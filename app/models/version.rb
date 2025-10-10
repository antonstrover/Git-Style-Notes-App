class Version < ApplicationRecord
  belongs_to :note
  belongs_to :author, class_name: "User"
  belongs_to :parent_version, class_name: "Version", optional: true
  has_many :child_versions, class_name: "Version", foreign_key: :parent_version_id

  validates :content, presence: true
  validates :summary, presence: true
  validates :note, presence: true
  validates :author, presence: true
  validates :version_number, uniqueness: { scope: :note_id }
  validate :parent_version_must_belong_to_same_note
  validate :content_is_immutable, on: :update
  validate :version_number_is_immutable, on: :update

  before_create :set_version_number

  private

  def set_version_number
    # Always recalculate version_number to override any database default
    # Lock the note to prevent race conditions during version creation
    locked_note = Note.lock.find(note_id)
    max_version = locked_note.versions.maximum(:version_number) || 0
    self.version_number = max_version + 1
  end

  def parent_version_must_belong_to_same_note
    if parent_version.present? && parent_version.note_id != note_id
      errors.add(:parent_version, "must belong to the same note")
    end
  end

  def content_is_immutable
    if content_changed?
      errors.add(:content, "cannot be changed after creation")
    end
  end

  def version_number_is_immutable
    if version_number_changed?
      errors.add(:version_number, "cannot be changed after creation")
    end
  end
end
