# frozen_string_literal: true

module Versions
  class Revert
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidTargetError < Error; end

    def initialize(note:, author:, target_version_id:, summary: nil)
      @note = note
      @author = author
      @target_version_id = target_version_id
      @summary = summary
    end

    def call
      validate_permissions!
      validate_target!

      ActiveRecord::Base.transaction do
        version = create_revert_version
        update_head_version(version)
        log_revert(version)
        version
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, "Failed to revert version: #{e.message}"
    end

    private

    attr_reader :note, :author, :target_version_id, :summary

    def validate_permissions!
      policy = NotePolicy.new(author, note)
      unless policy.update?
        raise UnauthorizedError, "Author does not have permission to revert versions"
      end
    end

    def validate_target!
      unless target_version && target_version.note_id == note.id
        raise InvalidTargetError, "Target version must belong to the same note"
      end
    end

    def target_version
      @target_version ||= Version.find_by(id: target_version_id)
    end

    def create_revert_version
      Version.create!(
        note: note,
        author: author,
        content: target_version.content,
        summary: summary || "Reverted to version #{target_version_id}",
        parent_version_id: note.head_version_id
      )
    end

    def update_head_version(version)
      note.update!(head_version_id: version.id)
    end

    def log_revert(version)
      Rails.logger.info(
        "Version reverted: new_version_id=#{version.id}, note_id=#{note.id}, " \
        "author_id=#{author.id}, target_version_id=#{target_version_id}"
      )
    end
  end
end
