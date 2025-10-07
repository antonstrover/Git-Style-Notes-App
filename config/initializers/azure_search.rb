# frozen_string_literal: true

# Azure Cognitive Search configuration
module AzureSearch
  class << self
    def configured?
      service_name.present? && api_key.present? && openai_endpoint.present? && openai_api_key.present?
    end

    def service_name
      ENV["AZURE_SEARCH_SERVICE_NAME"]
    end

    def index_name
      ENV.fetch("AZURE_SEARCH_INDEX_NAME", "notes")
    end

    def api_key
      ENV["AZURE_SEARCH_API_KEY"]
    end

    def api_version
      ENV.fetch("AZURE_SEARCH_API_VERSION", "2023-11-01")
    end

    def endpoint
      return nil unless service_name.present?
      "https://#{service_name}.search.windows.net"
    end

    def openai_endpoint
      ENV["AZURE_OPENAI_ENDPOINT"]
    end

    def openai_api_key
      ENV["AZURE_OPENAI_API_KEY"]
    end

    def openai_embedding_deployment
      ENV.fetch("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-3-large")
    end

    def openai_api_version
      ENV.fetch("AZURE_OPENAI_API_VERSION", "2024-02-01")
    end

    # Search configuration
    def batch_size
      ENV.fetch("SEARCH_BATCH_SIZE", 16).to_i
    end

    def embed_timeout_ms
      ENV.fetch("EMBED_TIMEOUT_MS", 30000).to_i
    end

    def search_timeout_ms
      ENV.fetch("SEARCH_TIMEOUT_MS", 10000).to_i
    end

    def max_chunks_per_version
      ENV.fetch("SEARCH_MAX_CHUNKS_PER_VERSION", 100).to_i
    end

    def chunk_size
      ENV.fetch("SEARCH_CHUNK_SIZE", 1000).to_i
    end

    def chunk_overlap
      ENV.fetch("SEARCH_CHUNK_OVERLAP", 150).to_i
    end

    def embedding_dimensions
      # text-embedding-3-large has 3072 dimensions
      # text-embedding-3-small has 1536 dimensions
      case openai_embedding_deployment
      when /large/
        3072
      when /small/
        1536
      else
        3072 # default
      end
    end
  end
end

# Log configuration status on boot
if defined?(Rails::Server)
  if AzureSearch.configured?
    Rails.logger.info "Azure Search configured: #{AzureSearch.endpoint}/indexes/#{AzureSearch.index_name}"
  else
    Rails.logger.warn "Azure Search not fully configured. Set required environment variables to enable search."
  end
end
