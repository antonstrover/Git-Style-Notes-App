class Note < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :versions, dependent: :destroy
  belongs_to :head_version, class_name: "Version", optional: true
  has_many :collaborators, dependent: :destroy
  has_many :collaborating_users, through: :collaborators, source: :user
  has_one :fork_as_target, class_name: "Fork", foreign_key: :target_note_id
  has_many :forks_as_source, class_name: "Fork", foreign_key: :source_note_id

  enum :visibility, { private: 'private', link: 'link', public: 'public' }, prefix: true

  validates :owner, presence: true
  validates :title, presence: true
  validates :visibility, presence: true, inclusion: { in: visibilities.keys }
end
