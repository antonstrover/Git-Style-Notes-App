# frozen_string_literal: true

module Search
  class Query
    class Error < StandardError; end

    # Perform hybrid search with ACL filtering
    #
    # @param query_text [String] The search query
    # @param user [User, nil] The current user (nil for anonymous)
    # @param top [Integer] Number of results to return
    # @param skip [Integer] Number of results to skip (pagination)
    # @param note_id [Integer, nil] Optional filter by note ID
    # @param enable_captions [Boolean] Enable semantic captions
    # @return [Hash] Search results
    def self.search(query_text:, user: nil, top: 20, skip: 0, note_id: nil, enable_captions: true)
      new.search(
        query_text: query_text,
        user: user,
        top: top,
        skip: skip,
        note_id: note_id,
        enable_captions: enable_captions
      )
    end

    # Get suggestions for autocomplete
    #
    # @param query_text [String] The query text
    # @param user [User, nil] The current user (nil for anonymous)
    # @param top [Integer] Number of suggestions
    # @return [Array<Hash>] Suggestions
    def self.suggest(query_text:, user: nil, top: 5)
      new.suggest(query_text: query_text, user: user, top: top)
    end

    def initialize
      @endpoint = AzureSearch.endpoint
      @index_name = AzureSearch.index_name
      @api_key = AzureSearch.api_key
      @api_version = AzureSearch.api_version
      @timeout = AzureSearch.search_timeout_ms / 1000.0
    end

    def search(query_text:, user:, top:, skip:, note_id:, enable_captions:)
      raise Error, "Query text cannot be empty" if query_text.blank?

      start_time = Time.now

      # Generate query embedding for vector search
      query_embedding = EmbeddingsClient.call([query_text]).first

      # Build search request
      search_request = build_search_request(
        query_text: query_text,
        query_embedding: query_embedding,
        user: user,
        top: top,
        skip: skip,
        note_id: note_id,
        enable_captions: enable_captions
      )

      # Execute search
      url = "#{@endpoint}/indexes/#{@index_name}/docs/search?api-version=#{@api_version}"

      response = HTTParty.post(
        url,
        headers: {
          "Content-Type" => "application/json",
          "api-key" => @api_key
        },
        body: search_request.to_json,
        timeout: @timeout
      )

      handle_search_response(response, query_text, Time.now - start_time)
    rescue => e
      Rails.logger.error("Query search failed: #{e.class} - #{e.message}")
      raise Error, "Search failed: #{e.message}"
    end

    def suggest(query_text:, user:, top:)
      raise Error, "Query text cannot be empty" if query_text.blank?

      url = "#{@endpoint}/indexes/#{@index_name}/docs/suggest?api-version=#{@api_version}"

      suggest_request = {
        search: query_text,
        suggesterName: "sg_notes_title",
        top: top,
        filter: build_acl_filter(user),
        select: "title,note_id"
      }

      response = HTTParty.post(
        url,
        headers: {
          "Content-Type" => "application/json",
          "api-key" => @api_key
        },
        body: suggest_request.to_json,
        timeout: @timeout
      )

      handle_suggest_response(response)
    rescue => e
      Rails.logger.error("Query suggest failed: #{e.class} - #{e.message}")
      raise Error, "Suggest failed: #{e.message}"
    end

    private

    def build_search_request(query_text:, query_embedding:, user:, top:, skip:, note_id:, enable_captions:)
      request = {
        search: query_text,
        top: top,
        skip: skip,
        filter: build_acl_filter(user, note_id),
        select: "id,note_id,version_id,title,content,updated_at",
        queryType: "semantic",
        semanticConfiguration: "semantic-config",
        vectorQueries: [
          {
            kind: "vector",
            vector: query_embedding,
            fields: "content_vector",
            k: 50 # Retrieve top 50 vector matches for hybrid ranking
          }
        ]
      }

      # Enable semantic captions if requested
      if enable_captions
        request[:answers] = "extractive|count-3"
        request[:captions] = "extractive|highlight-true"
      end

      request
    end

    def build_acl_filter(user, note_id = nil)
      filters = []

      # Note ID filter (optional)
      filters << "note_id eq #{note_id}" if note_id.present?

      # ACL filter
      if user.present?
        # Authenticated user can see:
        # 1. Public notes
        # 2. Notes they own
        # 3. Notes they're a collaborator on
        acl_filter = "(visibility eq 'public') or (owner_id eq #{user.id}) or (allowed_user_ids/any(uid: uid eq #{user.id}))"
        filters << acl_filter
      else
        # Anonymous users can only see public notes
        filters << "(visibility eq 'public')"
      end

      filters.join(" and ")
    end

    def handle_search_response(response, query_text, elapsed_time)
      case response.code
      when 200
        data = JSON.parse(response.body)
        results = data["value"] || []

        # Transform results to consistent format
        transformed_results = results.map do |result|
          {
            chunk_id: result["id"],
            note_id: result["note_id"],
            version_id: result["version_id"],
            title: result["title"],
            snippet: extract_snippet(result),
            score: result["@search.score"],
            updated_at: result["updated_at"]
          }
        end

        Rails.logger.info(
          "Query: Search completed for '#{query_text.truncate(50)}' - " \
          "#{transformed_results.size} results in #{elapsed_time.round(2)}s"
        )

        {
          results: transformed_results,
          total_count: data["@odata.count"],
          answers: data["@search.answers"]
        }
      when 400
        error_data = JSON.parse(response.body) rescue {}
        error_message = error_data.dig("error", "message") || response.body
        raise Error, "Bad request: #{error_message}"
      when 401
        raise Error, "Authentication failed. Check AZURE_SEARCH_API_KEY"
      when 404
        raise Error, "Index '#{@index_name}' not found. Run 'rake search:setup'"
      else
        raise Error, "Unexpected response: #{response.code} - #{response.body}"
      end
    end

    def handle_suggest_response(response)
      case response.code
      when 200
        data = JSON.parse(response.body)
        suggestions = data["value"] || []

        # Group by note_id and deduplicate titles
        unique_suggestions = suggestions
                               .uniq { |s| s["note_id"] }
                               .map { |s| { text: s["@search.text"], note_id: s["note_id"] } }

        unique_suggestions
      when 400
        error_data = JSON.parse(response.body) rescue {}
        error_message = error_data.dig("error", "message") || response.body
        raise Error, "Bad request: #{error_message}"
      when 401
        raise Error, "Authentication failed. Check AZURE_SEARCH_API_KEY"
      when 404
        raise Error, "Index '#{@index_name}' not found. Run 'rake search:setup'"
      else
        raise Error, "Unexpected response: #{response.code} - #{response.body}"
      end
    end

    def extract_snippet(result)
      # Prefer semantic caption if available
      if result["@search.captions"]&.any?
        caption = result["@search.captions"].first
        caption["highlights"] || caption["text"]
      else
        # Fallback to truncated content
        result["content"]&.truncate(200) || ""
      end
    end
  end
end
