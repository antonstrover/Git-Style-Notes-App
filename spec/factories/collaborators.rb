FactoryBot.define do
  factory :collaborator do
    association :note
    association :user
    role { :viewer }

    trait :editor do
      role { :editor }
    end

    trait :viewer do
      role { :viewer }
    end
  end
end
