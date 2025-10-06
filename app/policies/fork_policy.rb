# frozen_string_literal: true

class ForkPolicy < ApplicationPolicy
  def create?
    # Can fork any note the user can view
    NotePolicy.new(user, record).show?
  end

  def show?
    # Can see fork record if you can see either note
    source_policy.show? || target_policy.show?
  end

  private

  def source_policy
    @source_policy ||= NotePolicy.new(user, record.source_note)
  end

  def target_policy
    @target_policy ||= NotePolicy.new(user, record.target_note)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      note_ids = NotePolicy::Scope.new(user, Note).resolve.pluck(:id)
      scope.where("source_note_id IN (:ids) OR target_note_id IN (:ids)", ids: note_ids)
    end
  end
end
