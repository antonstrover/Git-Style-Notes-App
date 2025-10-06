class Collaborator < ApplicationRecord
  belongs_to :note
  belongs_to :user

  enum role: { viewer: 'viewer', editor: 'editor' }

  validates :note, presence: true
  validates :user, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :user_id, uniqueness: { scope: :note_id }
end
