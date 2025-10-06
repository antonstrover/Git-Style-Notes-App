# frozen_string_literal: true

module Versions
  class Create
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidParentError < Error; end

    def initialize(note:, author:, content:, summary: "", parent_version_id: nil)
      @note = note
      @author = author
      @content = content
      @summary = summary
      @parent_version_id = parent_version_id
    end

    def call
      validate_permissions!
      validate_parent! if @parent_version_id.present?

      ActiveRecord::Base.transaction do
        version = create_version
        update_head_version(version)
        log_creation(version)
        version
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, "Failed to create version: #{e.message}"
    end

    private

    attr_reader :note, :author, :content, :summary, :parent_version_id

    def validate_permissions!
      policy = NotePolicy.new(author, note)
      unless policy.update?
        raise UnauthorizedError, "Author does not have permission to create versions"
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
  end
end
