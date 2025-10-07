# frozen_string_literal: true

module Search
  class ReindexNoteJob < ApplicationJob
    queue_as :default

    retry_on Search::Indexer::Error, wait: :exponentially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    # Reindex a note (typically after permission/visibility changes)
    # Deletes old chunks and reindexes the current head version
    #
    # @param note_id [Integer] The note ID to reindex
    def perform(note_id)
      return unless AzureSearch.configured?

      note = Note.find(note_id)

      Rails.logger.info("ReindexNoteJob: Reindexing note #{note_id}")

      # First, delete existing chunks
      Search::Indexer.delete_by_note(note_id)

      # Reindex head version if it exists
      if note.head_version.present?
        Search::EmbeddingsJob.perform_later(note_id, note.head_version_id)
        Rails.logger.info("ReindexNoteJob: Enqueued EmbeddingsJob for note #{note_id}")
      else
        Rails.logger.info("ReindexNoteJob: Note #{note_id} has no head version, skipping indexing")
      end
    rescue => e
      Rails.logger.error("ReindexNoteJob failed for note #{note_id}: #{e.class} - #{e.message}")
      raise
    end
  end
end
