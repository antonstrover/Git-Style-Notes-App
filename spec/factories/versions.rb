FactoryBot.define do
  factory :version do
    association :note
    association :author, factory: :user
    content { Faker::Lorem.paragraph(sentence_count: 5) }
    summary { Faker::Lorem.sentence }
    parent_version { nil }

    trait :with_parent do
      transient do
        parent { nil }
      end

      after(:build) do |version, evaluator|
        version.parent_version = evaluator.parent || version.note.head_version
      end
    end
  end
end
