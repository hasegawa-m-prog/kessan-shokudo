class QuizRunQuestion < ApplicationRecord
  belongs_to :quiz_run
  belongs_to :question
  has_one :answer, dependent: :restrict_with_error
  validates :position, inclusion: { in: 1..5 }, uniqueness: { scope: :quiz_run_id }
  validates :question_id, uniqueness: { scope: :quiz_run_id }
  validate :review_has_one_position

  private

  def review_has_one_position
    errors.add(:position, "は復習では1です") if quiz_run&.kind == "review" && position != 1
  end
end
