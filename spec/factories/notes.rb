FactoryBot.define do
  factory :note do
    association :owner, factory: :user
    title { Faker::Lorem.sentence(word_count: 3) }
    visibility { :private }

    trait :with_head_version do
      after(:create) do |note|
        version = create(:version, note: note, author: note.owner)
        note.update_column(:head_version_id, version.id)
      end
    end

    trait :public_note do
      visibility { :public }
    end

    trait :link_visible do
      visibility { :link }
    end
  end
end
