require "rails_helper"

RSpec.describe User, type: :model do
  it "validates factory data and stores a digest, not the password" do
    user = create(:user)
    expect(user.password_digest).not_to eq(user.password)
    expect(user.authenticate("test-password-123")).to eq(user)
    expect(user.authenticate("wrong")).to be(false)
  end

  it "normalizes email before persisting" do
    expect(create(:user, email: "  LEARNER@example.COM ").email).to eq("learner@example.com")
  end

  it "rejects case-insensitive duplicates" do
    create(:user, email: "learner@example.com")
    expect(build(:user, email: " LEARNER@example.com ")).not_to be_valid
  end

  it "rejects missing and malformed email" do
    [ nil, "", "not-an-email" ].each do |email|
      expect(build(:user, email: email)).not_to be_valid
    end
  end

  it "rejects short or missing passwords" do
    [ nil, "", "short" ].each do |password|
      expect(build(:user, password: password)).not_to be_valid
    end
  end

  it "rejects mismatched or missing confirmation" do
    [ nil, "", "different-password" ].each do |confirmation|
      expect(build(:user, password_confirmation: confirmation)).not_to be_valid
    end
  end

  it "rejects passwords over bcrypt's 72-byte limit" do
    expect(build(:user, password: "あ" * 25)).not_to be_valid
  end

  it "keeps email uniqueness enforced at the database level" do
    user = create(:user)
    expect do
      User.transaction(requires_new: true) do
        User.insert_all!([ { email: user.email, password_digest: user.password_digest, created_at: Time.current, updated_at: Time.current } ])
      end
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
