# frozen_string_literal: true

class VersionPolicy < ApplicationPolicy
  def index?
    note_policy.show?
  end

  def show?
    note_policy.show?
  end

  def create?
    note_policy.owner? || note_policy.editor?
  end

  def revert?
    create? # Same permission as creating a version
  end

  private

  def note_policy
    @note_policy ||= NotePolicy.new(user, record.note)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Versions are accessed through notes, filter by note visibility
      note_ids = NotePolicy::Scope.new(user, Note).resolve.pluck(:id)
      scope.where(note_id: note_ids)
    end
  end
end
