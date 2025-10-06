# frozen_string_literal: true

module Versions
  class Create
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidParentError < Error; end
    class ConflictError < Error; end

    def initialize(note:, author:, content:, summary: "", parent_version_id: nil, base_version_id: nil)
      @note = note
      @author = author
      @content = content
      @summary = summary
      # Support both parent_version_id and base_version_id (API uses base_version_id)
      @parent_version_id = parent_version_id || base_version_id
      @base_version_id = base_version_id || parent_version_id
    end

    def call
      validate_permissions!
      detect_conflict! if @base_version_id.present?
      validate_parent! if @parent_version_id.present?

      version = nil
      ActiveRecord::Base.transaction do
        version = create_version
        update_head_version(version)
        log_creation(version)
      end

      # Broadcast outside transaction to avoid locks
      broadcast_version_created(version) if version
      version
    rescue ActiveRecord::RecordInvalid => e
      raise Error, "Failed to create version: #{e.message}"
    end

    private

    attr_reader :note, :author, :content, :summary, :parent_version_id, :base_version_id

    def validate_permissions!
      policy = NotePolicy.new(author, note)
      unless policy.create_version?
        raise UnauthorizedError, "Author does not have permission to create versions"
      end
    end

    def detect_conflict!
      # If base_version_id is provided but doesn't match current head, we have a conflict
      if @base_version_id.present? && note.head_version_id != @base_version_id
        broadcast_conflict_notice
        raise ConflictError, "Version conflict: base version #{@base_version_id} does not match current head #{note.head_version_id}"
      end
    end

    def validate_parent!
      parent = Version.find_by(id: parent_version_id)
      unless parent && parent.note_id == note.id
        raise InvalidParentError, "Parent version must belong to the same note"
      end
    end

    def create_version
      Version.create!(
        note: note,
        author: author,
        content: content,
        summary: summary,
        parent_version_id: resolved_parent_id
      )
    end

    def resolved_parent_id
      parent_version_id || note.head_version_id
    end

    def update_head_version(version)
      note.update!(head_version_id: version.id)
    end

    def log_creation(version)
      Rails.logger.info(
        "Version created: id=#{version.id}, note_id=#{note.id}, " \
        "author_id=#{author.id}, parent_id=#{version.parent_version_id}"
      )
    end

    def broadcast_version_created(version)
      ActionCable.server.broadcast(
        "notes:#{note.id}",
        {
          type: "version_created",
          note_id: note.id,
          version_id: version.id,
          head_version_id: note.head_version_id,
          author: {
            id: author.id,
            email: author.email
          },
          created_at: version.created_at.iso8601,
          summary: version.summary
        }
      )

      Rails.logger.info "Broadcast version_created: version_id=#{version.id}, note_id=#{note.id}"
    end

    def broadcast_conflict_notice
      ActionCable.server.broadcast(
        "notes:#{note.id}",
        {
          type: "conflict_notice",
          note_id: note.id,
          head_version_id: note.head_version_id,
          message: "Another user has updated this note. Your version is based on an older state."
        }
      )

      Rails.logger.info "Broadcast conflict_notice: note_id=#{note.id}, base=#{@base_version_id}, head=#{note.head_version_id}"
    end
  end
end
