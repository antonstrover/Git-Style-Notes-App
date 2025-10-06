FactoryBot.define do
  factory :fork do
    association :source_note, factory: :note
    association :target_note, factory: :note
  end
end
