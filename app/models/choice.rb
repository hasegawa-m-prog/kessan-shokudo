class Choice < ApplicationRecord
  include PublishedContent
  belongs_to :question
  has_many :answers, dependent: :restrict_with_error
  validates :body, presence: true
  validates :position, inclusion: { in: 1..3 }, uniqueness: { scope: :question_id }
  validates :is_correct, inclusion: { in: [ true, false ] }

  private

  def protected_questions
    Question.where(id: [ question_id, question_id_in_database ])
  end
end
