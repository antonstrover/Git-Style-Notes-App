# frozen_string_literal: true

class CollaboratorPolicy < ApplicationPolicy
  def index?
    note_policy.show?
  end

  def show?
    note_policy.show?
  end

  def create?
    note_policy.owner?
  end

  def destroy?
    note_policy.owner?
  end

  private

  def note_policy
    @note_policy ||= NotePolicy.new(user, record.note)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      note_ids = NotePolicy::Scope.new(user, Note).resolve.pluck(:id)
      scope.where(note_id: note_ids)
    end
  end
end
