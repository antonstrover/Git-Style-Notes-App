class Version < ApplicationRecord
  belongs_to :note
  belongs_to :author, class_name: "User"
  belongs_to :parent_version, class_name: "Version", optional: true
  has_many :child_versions, class_name: "Version", foreign_key: :parent_version_id

  validates :content, presence: true
  validates :summary, presence: true
  validates :note, presence: true
  validates :author, presence: true
  validate :parent_version_must_belong_to_same_note
  validate :content_is_immutable, on: :update

  private

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
end
