class QuizRun < ApplicationRecord
  belongs_to :user
  belongs_to :industry, optional: true
  has_many :quiz_run_questions, -> { order(:position) }, dependent: :restrict_with_error
  has_many :answers, through: :quiz_run_questions
  validates :kind, inclusion: { in: %w[quiz review] }
  validates :started_at, presence: true
end
