# frozen_string_literal: true

module Search
  class EmbeddingsClient
    class Error < StandardError; end
    class TimeoutError < Error; end
    class QuotaExceededError < Error; end
    class DimensionMismatchError < Error; end

    MAX_RETRIES = 3
    INITIAL_BACKOFF = 1 # seconds

    # Generate embeddings for an array of text strings
    #
    # @param texts [Array<String>] Array of texts to embed
    # @return [Array<Array<Float>>] Array of embedding vectors (preserves order)
    def self.call(texts)
      new.call(texts)
    end

    def initialize
      @endpoint = AzureSearch.openai_endpoint
      @api_key = AzureSearch.openai_api_key
      @deployment = AzureSearch.openai_embedding_deployment
      @api_version = AzureSearch.openai_api_version
      @batch_size = AzureSearch.batch_size
      @timeout_ms = AzureSearch.embed_timeout_ms
      @expected_dimensions = AzureSearch.embedding_dimensions
    end

    def call(texts)
      raise Error, "Texts array cannot be empty" if texts.empty?

      start_time = Time.now
      all_embeddings = []

      texts.each_slice(@batch_size).with_index do |batch, batch_index|
        batch_embeddings = generate_embeddings_with_retry(batch)
        all_embeddings.concat(batch_embeddings)

        log_batch_metrics(batch_index, batch.size, Time.now - start_time)
      end

      validate_dimensions!(all_embeddings)
      all_embeddings
    rescue => e
      Rails.logger.error(
        "EmbeddingsClient failed: #{e.class} - #{e.message}\n" \
        "Texts count: #{texts.size}, Expected dimensions: #{@expected_dimensions}"
      )
      raise
    end

    private

    def generate_embeddings_with_retry(texts)
      attempt = 0

      begin
        attempt += 1
        generate_embeddings(texts)
      rescue QuotaExceededError => e
        if attempt < MAX_RETRIES
          backoff_time = calculate_backoff(attempt)
          Rails.logger.warn(
            "EmbeddingsClient: Quota exceeded (attempt #{attempt}/#{MAX_RETRIES}), " \
            "retrying in #{backoff_time}s"
          )
          sleep(backoff_time)
          retry
        else
          raise
        end
      rescue Timeout::Error, HTTParty::Error => e
        if attempt < MAX_RETRIES
          backoff_time = calculate_backoff(attempt)
          Rails.logger.warn(
            "EmbeddingsClient: #{e.class} (attempt #{attempt}/#{MAX_RETRIES}), " \
            "retrying in #{backoff_time}s"
          )
          sleep(backoff_time)
          retry
        else
          raise TimeoutError, "Failed after #{MAX_RETRIES} attempts: #{e.message}"
        end
      end
    end

    def generate_embeddings(texts)
      url = "#{@endpoint}/openai/deployments/#{@deployment}/embeddings?api-version=#{@api_version}"

      response = HTTParty.post(
        url,
        headers: {
          "Content-Type" => "application/json",
          "api-key" => @api_key
        },
        body: {
          input: texts
        }.to_json,
        timeout: @timeout_ms / 1000.0
      )

      handle_response(response)
    end

    def handle_response(response)
      case response.code
      when 200
        data = JSON.parse(response.body)
        embeddings = data["data"].sort_by { |item| item["index"] }.map { |item| item["embedding"] }

        # Log usage without exposing content
        log_usage(data["usage"]) if data["usage"]

        embeddings
      when 429
        retry_after = response.headers["retry-after"]&.to_i || calculate_backoff(1)
        sleep(retry_after) if retry_after > 0
        raise QuotaExceededError, "Rate limit exceeded. Retry after #{retry_after}s"
      when 400
        error_message = JSON.parse(response.body)["error"]["message"] rescue response.body
        raise Error, "Bad request: #{error_message}"
      when 401
        raise Error, "Authentication failed. Check AZURE_OPENAI_API_KEY"
      when 404
        raise Error, "Deployment '#{@deployment}' not found. Check AZURE_OPENAI_EMBEDDING_DEPLOYMENT"
      else
        raise Error, "Unexpected response: #{response.code} - #{response.body}"
      end
    end

    def calculate_backoff(attempt)
      # Exponential backoff with jitter: base * 2^(attempt-1) + random(0-1)
      (INITIAL_BACKOFF * (2 ** (attempt - 1))) + rand
    end

    def validate_dimensions!(embeddings)
      embeddings.each_with_index do |embedding, index|
        if embedding.size != @expected_dimensions
          raise DimensionMismatchError,
                "Embedding #{index} has #{embedding.size} dimensions, expected #{@expected_dimensions}"
        end
      end
    end

    def log_usage(usage)
      Rails.logger.info(
        "EmbeddingsClient: Generated embeddings - " \
        "prompt_tokens: #{usage['prompt_tokens']}, " \
        "total_tokens: #{usage['total_tokens']}"
      )
    end

    def log_batch_metrics(batch_index, batch_size, elapsed_time)
      Rails.logger.debug(
        "EmbeddingsClient: Batch #{batch_index} completed - " \
        "size: #{batch_size}, " \
        "elapsed: #{elapsed_time.round(2)}s"
      )
    end
  end
end
