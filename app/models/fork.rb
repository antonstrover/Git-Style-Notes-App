class Fork < ApplicationRecord
  belongs_to :source_note, class_name: "Note"
  belongs_to :target_note, class_name: "Note"

  validates :source_note, presence: true
  validates :target_note, presence: true
  validates :target_note_id, uniqueness: true
  validate :source_and_target_must_be_different

  private

  def source_and_target_must_be_different
    if source_note_id.present? && source_note_id == target_note_id
      errors.add(:target_note, "cannot be the same as source note")
    end
  end
end
