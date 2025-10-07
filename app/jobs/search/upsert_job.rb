# frozen_string_literal: true

module Search
  class UpsertJob < ApplicationJob
    queue_as :default

    retry_on Search::Indexer::Error, wait: :exponentially_longer, attempts: 3

    # Upsert prepared documents to Azure Search
    #
    # @param documents [Array<Hash>] Array of documents with embeddings
    def perform(documents)
      return unless AzureSearch.configured?
      return if documents.empty?

      Rails.logger.info("UpsertJob: Upserting #{documents.size} documents to Azure Search")

      result = Search::Indexer.upsert(documents)

      Rails.logger.info(
        "UpsertJob: Completed - uploaded: #{result[:uploaded]}, failed: #{result[:failed]}"
      )

      if result[:failed] > 0
        Rails.logger.warn(
          "UpsertJob: #{result[:failed]} documents failed to upsert. Check Azure Search logs."
        )
      end
    rescue => e
      Rails.logger.error("UpsertJob failed: #{e.class} - #{e.message}")
      raise
    end
  end
end
