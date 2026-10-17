class Industry < ApplicationRecord
  NAMES = %w[小売業 製造業 サービス業].freeze
  has_many :questions, dependent: :restrict_with_error
  has_many :quiz_runs, dependent: :restrict_with_error
  validates :name, inclusion: { in: NAMES }, uniqueness: true
end
