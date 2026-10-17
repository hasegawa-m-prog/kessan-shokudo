require "rails_helper"
require Rails.root.join("lib/demo_learning_content")

RSpec.describe Answer, type: :model do
  before { DemoLearningContent.load! }

  it "requires a choice from the question, and preserves saved answers" do
    user = create(:user)
    attempt = QuizAttempt.start(session: {}, user: user, industry: Industry.first)
    entry = user.quiz_runs.sole.quiz_run_questions.first
    foreign_choice = Choice.where.not(question_id: entry.question_id).first
    expect(entry.build_answer(choice: foreign_choice, answered_at: Time.current)).not_to be_valid
    correct = entry.question.correct_choice
    attempt.answer!(position: 1, choice_id: correct.id, token: attempt.token)
    answer = entry.reload.answer
    expect(answer).to be_correct
    expect(answer.update(choice: entry.question.choices.where(is_correct: false).first)).to be(false)
    expect(Answer.new(quiz_run_question: entry, choice: correct, answered_at: Time.current)).not_to be_valid
  end

  it "does not load another user's run even if a stored run id is supplied" do
    owner = create(:user)
    state = {}
    QuizAttempt.start(session: state, user: owner, industry: Industry.first)
    expect { QuizAttempt.new(session: state, user: create(:user)) }.to raise_error(QuizAttempt::Expired)
  end
end
