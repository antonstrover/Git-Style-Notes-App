# frozen_string_literal: true

module Search
  class Chunker
    class Error < StandardError; end

    # Chunk a note's content into overlapping windows for better search recall
    #
    # @param note [Note] The note to chunk
    # @param version [Version] The version to chunk
    # @return [Array<Hash>] Array of chunk hashes with :id, :content, :title, :ordinal
    def self.call(note:, version:)
      new(note: note, version: version).call
    end

    def initialize(note:, version:)
      @note = note
      @version = version
      @chunk_size = AzureSearch.chunk_size
      @chunk_overlap = AzureSearch.chunk_overlap
      @max_chunks = AzureSearch.max_chunks_per_version
    end

    def call
      content = @version.content.strip
      return [build_single_chunk(content, 0)] if content.length <= @chunk_size

      chunks = []
      start_pos = 0
      ordinal = 0

      while start_pos < content.length && ordinal < @max_chunks
        # Calculate end position for this chunk
        end_pos = [start_pos + @chunk_size, content.length].min

        # Try to break at paragraph boundary if we're not at the end
        if end_pos < content.length
          # Look for paragraph break (double newline) or single newline
          paragraph_break = content.rindex("\n\n", end_pos)
          newline_break = content.rindex("\n", end_pos)

          # Use paragraph break if within reasonable range
          if paragraph_break && paragraph_break > start_pos && (end_pos - paragraph_break) < (@chunk_size * 0.2)
            end_pos = paragraph_break + 2 # Include the double newline
          elsif newline_break && newline_break > start_pos && (end_pos - newline_break) < (@chunk_size * 0.1)
            end_pos = newline_break + 1 # Include the newline
          end
        end

        chunk_content = content[start_pos...end_pos].strip
        chunks << build_chunk(chunk_content, ordinal) if chunk_content.present?

        # Move start position forward, accounting for overlap
        start_pos = end_pos - @chunk_overlap
        start_pos = [start_pos, content.length].min

        ordinal += 1
      end

      if ordinal >= @max_chunks && start_pos < content.length
        Rails.logger.warn(
          "Chunker: Max chunks (#{@max_chunks}) reached for note #{@note.id}, " \
          "version #{@version.id}. Remaining content truncated."
        )
      end

      chunks
    end

    private

    def build_chunk(content, ordinal)
      {
        id: chunk_id(ordinal),
        content: content,
        title: @note.title,
        ordinal: ordinal
      }
    end

    def build_single_chunk(content, ordinal)
      build_chunk(content, ordinal)
    end

    def chunk_id(ordinal)
      "note:#{@note.id}:version:#{@version.id}:chunk:#{ordinal}"
    end
  end
end
