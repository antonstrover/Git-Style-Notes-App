# frozen_string_literal: true

module Search
  class Indexer
    class Error < StandardError; end

    # Upsert documents to Azure Search
    #
    # @param documents [Array<Hash>] Array of document hashes to upsert
    # @return [Hash] Response with counts
    def self.upsert(documents)
      new.upsert(documents)
    end

    # Delete documents by note_id
    #
    # @param note_id [Integer] The note ID to delete all chunks for
    # @return [Boolean] Success status
    def self.delete_by_note(note_id)
      new.delete_by_note(note_id)
    end

    def initialize
      @endpoint = AzureSearch.endpoint
      @index_name = AzureSearch.index_name
      @api_key = AzureSearch.api_key
      @api_version = AzureSearch.api_version
      @timeout = AzureSearch.search_timeout_ms / 1000.0
    end

    def upsert(documents)
      return { uploaded: 0, failed: 0 } if documents.empty?

      start_time = Time.now
      url = "#{@endpoint}/indexes/#{@index_name}/docs/index?api-version=#{@api_version}"

      # Azure Search uses "mergeOrUpload" action for idempotent upserts
      payload = {
        value: documents.map { |doc| doc.merge("@search.action" => "mergeOrUpload") }
      }

      response = HTTParty.post(
        url,
        headers: {
          "Content-Type" => "application/json",
          "api-key" => @api_key
        },
        body: payload.to_json,
        timeout: @timeout
      )

      handle_upsert_response(response, documents.size, Time.now - start_time)
    rescue => e
      Rails.logger.error(
        "Indexer upsert failed: #{e.class} - #{e.message}\n" \
        "Documents count: #{documents.size}"
      )
      raise Error, "Upsert failed: #{e.message}"
    end

    def delete_by_note(note_id)
      # First, search for all chunk IDs for this note
      search_url = "#{@endpoint}/indexes/#{@index_name}/docs?api-version=#{@api_version}&$filter=note_id eq #{note_id}&$select=id"

      search_response = HTTParty.get(
        search_url,
        headers: {
          "api-key" => @api_key
        },
        timeout: @timeout
      )

      unless search_response.success?
        Rails.logger.error("Indexer: Failed to find chunks for note #{note_id}: #{search_response.code}")
        return false
      end

      data = JSON.parse(search_response.body)
      chunk_ids = data["value"].map { |doc| doc["id"] }

      return true if chunk_ids.empty? # Nothing to delete

      # Delete all found chunks
      delete_url = "#{@endpoint}/indexes/#{@index_name}/docs/index?api-version=#{@api_version}"

      delete_payload = {
        value: chunk_ids.map { |id| { "@search.action" => "delete", "id" => id } }
      }

      delete_response = HTTParty.post(
        delete_url,
        headers: {
          "Content-Type" => "application/json",
          "api-key" => @api_key
        },
        body: delete_payload.to_json,
        timeout: @timeout
      )

      if delete_response.success?
        Rails.logger.info("Indexer: Deleted #{chunk_ids.size} chunks for note #{note_id}")
        true
      else
        Rails.logger.error(
          "Indexer: Failed to delete chunks for note #{note_id}: #{delete_response.code} - #{delete_response.body}"
        )
        false
      end
    rescue => e
      Rails.logger.error("Indexer delete_by_note failed: #{e.class} - #{e.message}")
      false
    end

    # Build a search document from chunked content with ACL metadata
    #
    # @param note [Note] The note
    # @param version [Version] The version
    # @param chunk [Hash] Chunk from Chunker with :id, :content, :title
    # @param title_vector [Array<Float>] Embedding for title
    # @param content_vector [Array<Float>] Embedding for content
    # @return [Hash] Document ready for Azure Search
    def self.build_document(note:, version:, chunk:, title_vector:, content_vector:)
      {
        id: chunk[:id],
        note_id: note.id,
        version_id: version.id,
        title: chunk[:title],
        content: chunk[:content],
        visibility: note.visibility,
        owner_id: note.owner_id,
        allowed_user_ids: build_allowed_user_ids(note),
        created_at: version.created_at.iso8601,
        updated_at: version.updated_at.iso8601,
        title_vector: title_vector,
        content_vector: content_vector
      }
    end

    private

    def handle_upsert_response(response, document_count, elapsed_time)
      case response.code
      when 200, 201
        data = JSON.parse(response.body)
        results = data["value"] || []

        successful = results.count { |r| r["status"] }
        failed = results.count { |r| !r["status"] }

        Rails.logger.info(
          "Indexer: Upserted #{successful}/#{document_count} documents " \
          "in #{elapsed_time.round(2)}s (#{failed} failed)"
        )

        if failed > 0
          Rails.logger.warn(
            "Indexer: Failed documents: #{results.select { |r| !r['status'] }.map { |r| r['key'] }}"
          )
        end

        { uploaded: successful, failed: failed }
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

    def self.build_allowed_user_ids(note)
      return [] if note.visibility_public?

      # Include owner and all collaborators
      user_ids = [note.owner_id]
      user_ids += note.collaborators.pluck(:user_id)

      # For link-shareable notes, include a special marker (-1)
      # This allows filtering for users with a valid link token
      user_ids << -1 if note.visibility_link?

      user_ids.uniq
    end
  end
end
