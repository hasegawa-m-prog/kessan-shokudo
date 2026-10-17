class Answer < ApplicationRecord
  scope :reviewable, -> { joins(:choice, quiz_run_question: :question).where(choices: { is_correct: false }).merge(Question.available) }
  belongs_to :quiz_run_question
  belongs_to :choice
  validates :quiz_run_question_id, uniqueness: true
  validates :answered_at, presence: true
  validate :choice_belongs_to_question
  validate :confirmed_answer_is_immutable, on: :update

  def correct?
    choice.is_correct
  end

  private

  def choice_belongs_to_question
    if choice && quiz_run_question && choice.question_id != quiz_run_question.question_id
      errors.add(:choice, "は出題された問題の選択肢を選んでください")
    end
  end

  def confirmed_answer_is_immutable
    errors.add(:base, "確定した回答は変更できません") if changed?
  end
end
