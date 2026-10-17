class QuizRun < ApplicationRecord
  scope :with_answers, -> { where(id: QuizRunQuestion.joins(:answer).select(:quiz_run_id)) }
  belongs_to :user
  belongs_to :industry, optional: true
  has_many :quiz_run_questions, -> { order(:position) }, dependent: :restrict_with_error
  has_many :answers, through: :quiz_run_questions
  validates :kind, inclusion: { in: %w[quiz review] }
  validates :started_at, presence: true

  def answered_entries
    quiz_run_questions.select(&:answer)
  end

  def correct_count
    answered_entries.count { |entry| entry.answer.correct? }
  end
end
