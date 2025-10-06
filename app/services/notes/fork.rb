# frozen_string_literal: true

module Notes
  class Fork
    class Error < StandardError; end
    class UnauthorizedError < Error; end

    def initialize(source_note:, new_owner:)
      @source_note = source_note
      @new_owner = new_owner
    end

    def call
      validate_permissions!

      ActiveRecord::Base.transaction do
        forked_note = create_forked_note
        initial_version = create_initial_version(forked_note)
        update_head_version(forked_note, initial_version)
        create_fork_record(forked_note)
        log_fork(forked_note)
        forked_note
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, "Failed to fork note: #{e.message}"
    end

    private

    attr_reader :source_note, :new_owner

    def validate_permissions!
      policy = NotePolicy.new(new_owner, source_note)
      unless policy.show?
        raise UnauthorizedError, "User does not have permission to view source note"
      end
    end

    def create_forked_note
      # NOTE: We do not copy collaborators for security/privacy reasons.
      # The forked note is private by default and owned solely by new_owner.
      Note.create!(
        owner: new_owner,
        title: "#{source_note.title} (fork)",
        visibility: 'private'
      )
    end

    def create_initial_version(forked_note)
      Version.create!(
        note: forked_note,
        author: new_owner,
        content: source_note.head_version.content,
        summary: "Forked from note #{source_note.id}",
        parent_version_id: nil
      )
    end

    def update_head_version(forked_note, version)
      forked_note.update!(head_version_id: version.id)
    end

    def create_fork_record(forked_note)
      Fork.create!(
        source_note: source_note,
        target_note: forked_note
      )
    end

    def log_fork(forked_note)
      Rails.logger.info(
        "Note forked: source_note_id=#{source_note.id}, " \
        "target_note_id=#{forked_note.id}, new_owner_id=#{new_owner.id}"
      )
    end
  end
end
