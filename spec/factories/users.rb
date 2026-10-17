FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "learner#{n}@example.com" }
    password { "test-password-123" }
    password_confirmation { password }
  end
end
