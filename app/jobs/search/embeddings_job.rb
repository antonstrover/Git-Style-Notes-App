# frozen_string_literal: true

module Search
  class EmbeddingsJob < ApplicationJob
    queue_as :default

    retry_on Search::EmbeddingsClient::QuotaExceededError, wait: :exponentially_longer, attempts: 5
    retry_on Search::EmbeddingsClient::TimeoutError, wait: 30.seconds, attempts: 3
    discard_on Search::EmbeddingsClient::DimensionMismatchError
    discard_on ActiveRecord::RecordNotFound

    # Generate embeddings and enqueue upsert for a note version
    #
    # @param note_id [Integer] The note ID
    # @param version_id [Integer] The version ID
    def perform(note_id, version_id)
      return unless AzureSearch.configured?

      note = Note.includes(:collaborators).find(note_id)
      version = Version.find(version_id)

      Rails.logger.info(
        "EmbeddingsJob: Processing note #{note_id}, version #{version_id}"
      )

      # Chunk the content
      chunks = Search::Chunker.call(note: note, version: version)

      if chunks.empty?
        Rails.logger.warn("EmbeddingsJob: No chunks generated for note #{note_id}, version #{version_id}")
        return
      end

      # Generate embeddings for titles and contents
      title_texts = chunks.map { |chunk| chunk[:title] }
      content_texts = chunks.map { |chunk| chunk[:content] }

      title_vectors = Search::EmbeddingsClient.call(title_texts)
      content_vectors = Search::EmbeddingsClient.call(content_texts)

      # Build documents
      documents = chunks.each_with_index.map do |chunk, index|
        Search::Indexer.build_document(
          note: note,
          version: version,
          chunk: chunk,
          title_vector: title_vectors[index],
          content_vector: content_vectors[index]
        )
      end

      # Enqueue upsert job
      Search::UpsertJob.perform_later(documents)

      Rails.logger.info(
        "EmbeddingsJob: Generated #{chunks.size} chunks with embeddings for note #{note_id}"
      )
    rescue => e
      Rails.logger.error(
        "EmbeddingsJob failed for note #{note_id}, version #{version_id}: " \
        "#{e.class} - #{e.message}"
      )
      raise
    end
  end
end
