# frozen_string_literal: true

class NotePolicy < ApplicationPolicy
  def index?
    true # Any authenticated user can list (scope filters appropriately)
  end

  def show?
    owner? || viewer? || editor? || public_or_link_visible?
  end

  def create?
    true # Any authenticated user can create notes
  end

  def update?
    owner? # Only owner can update title/visibility
  end

  def destroy?
    owner? # Only owner can delete
  end

  def fork?
    show? # Can fork any note you can view
  end

  def manage_collaborators?
    owner? # Only owner can manage collaborators
  end

  def create_version?
    owner? || editor? # Owner and editors can create versions
  end

  private

  def public_or_link_visible?
    record.public? || record.link?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.left_joins(:collaborators)
           .where(
             "notes.owner_id = :user_id OR " \
             "notes.visibility IN (:public_visibility) OR " \
             "collaborators.user_id = :user_id",
             user_id: user.id,
             public_visibility: %w[public link]
           )
           .distinct
    end
  end
end
