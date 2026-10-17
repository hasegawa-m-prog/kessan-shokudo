class User < ApplicationRecord
  has_many :quiz_runs, dependent: :restrict_with_error
  has_secure_password
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 12 }, if: -> { new_record? || password.present? }
  validates :password_confirmation, presence: true, if: -> { new_record? || password.present? }
end
