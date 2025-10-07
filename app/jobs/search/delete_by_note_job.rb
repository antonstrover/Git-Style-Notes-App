# frozen_string_literal: true

module Search
  class DeleteByNoteJob < ApplicationJob
    queue_as :default

    retry_on Search::Indexer::Error, wait: :exponentially_longer, attempts: 3

    # Delete all search index entries for a note
    #
    # @param note_id [Integer] The note ID to delete chunks for
    def perform(note_id)
      return unless AzureSearch.configured?

      Rails.logger.info("DeleteByNoteJob: Deleting all chunks for note #{note_id}")

      success = Search::Indexer.delete_by_note(note_id)

      if success
        Rails.logger.info("DeleteByNoteJob: Successfully deleted chunks for note #{note_id}")
      else
        Rails.logger.warn("DeleteByNoteJob: Failed to delete chunks for note #{note_id}")
        raise Search::Indexer::Error, "Failed to delete chunks for note #{note_id}"
      end
    rescue => e
      Rails.logger.error("DeleteByNoteJob failed for note #{note_id}: #{e.class} - #{e.message}")
      raise
    end
  end
end
