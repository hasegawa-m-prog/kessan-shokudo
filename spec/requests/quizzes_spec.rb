require "rails_helper"
require Rails.root.join("lib/demo_learning_content")

RSpec.describe "Five-question learning flow", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  before { DemoLearningContent.load! }

  def start_quiz(industry = Industry.first)
    post quiz_path, params: { industry_id: industry&.id || "random" }
    follow_redirect! if response.redirect?
  end

  def form_data
    html = Nokogiri::HTML(response.body)
    {
      position: html.at_css('input[name="position"]')["value"],
      attempt_token: html.at_css('input[name="attempt_token"]')["value"],
      choice_id: html.at_css('input[name="choice_id"]')["value"]
    }
  end

  it "offers only the planned industries and random selection" do
    get new_quiz_path
    expect(response).to have_http_status(:ok)
    (Industry::NAMES + [ "おまかせ" ]).each { |name| expect(response.body).to include(name) }
    expect(Nokogiri::HTML(response.body).css('input[type="radio"]').size).to eq(4)
  end

  it "rejects invalid industries and refuses a run with fewer than five questions" do
    post quiz_path, params: { industry_id: "bogus" }
    expect(response).to redirect_to(new_quiz_path)
    Question.first.retire!
    post quiz_path, params: { industry_id: Industry.first.id }
    expect(response).to redirect_to(new_quiz_path)
    follow_redirect!
    expect(response.body).to include("5問")
  end

  it "runs all five guest questions, shows server-judged results and writes no learning records" do
    expect do
      start_quiz(nil)
      questions = []
      5.times do |index|
        data = form_data
        question = Choice.find(data[:choice_id]).question
        questions << question.id
        expect(response.body).not_to include(question.explanation)
        data[:choice_id] = question.choices.find_by!(is_correct: index.even?).id
        post answer_quiz_path, params: data.merge(is_correct: true, score: 5)
        follow_redirect!
        expect(response.body).to include(index.even? ? "○ 正解です" : "× 不正解です", question.explanation)
        get quiz_path(position: index + 2) unless index == 4
      end
      expect(questions.uniq.size).to eq(5)
      get result_quiz_path
      expect(response.body).to include("3問", "ゲストの回答は履歴に保存されません")
      expect(response).to have_http_status(:ok)
    end.not_to change { [ QuizRun.count, QuizRunQuestion.count, Answer.count ] }
  end

  it "shows two company diagrams before an answer but hides the after-transaction diagram" do
    ids = Question.where(industry: Industry.first).order(:id).pluck(:id)
    allow(QuestionPicker).to receive(:call).and_return(ids)
    start_quiz
    expect(Nokogiri::HTML(response.body).css('.balance-sheet').size).to eq(2)
    post answer_quiz_path, params: form_data
    get quiz_path(position: 2)
    question = Question.find(ids[1])
    expect(Nokogiri::HTML(response.body).css('.balance-sheet').size).to eq(1)
    expect(response.body).not_to include('data-sheet-position="2"', question.explanation)
    post answer_quiz_path, params: form_data
    follow_redirect!
    expect(Nokogiri::HTML(response.body).css('.balance-sheet').size).to eq(2)
    expect(response.body).to include("増減を文字で確認", "1,000,000円減少", "1,000,000円増加")
  end

  it "rejects missing choices and choices from another question" do
    start_quiz
    data = form_data
    post answer_quiz_path, params: data.except(:choice_id)
    expect(response).to have_http_status(:unprocessable_content)
    other = Choice.where.not(question_id: Choice.find(data[:choice_id]).question_id).first
    post answer_quiz_path, params: data.merge(choice_id: other.id)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("1つ選んで")
  end

  it "rejects skipping ahead, forged positions, and premature result viewing" do
    start_quiz
    data = form_data
    [ "2", "0", "-1", "100", "1oops" ].each do |position|
      post answer_quiz_path, params: data.merge(position: position)
      expect(response).to redirect_to(quiz_path)
    end
    get quiz_path(position: 5)
    expect(response).to redirect_to(quiz_path)
    get result_quiz_path
    expect(response).to redirect_to(quiz_path)
  end

  it "preserves the first answer on duplicate submissions and does not corrupt a new attempt" do
    start_quiz
    old = form_data
    post answer_quiz_path, params: old
    post answer_quiz_path, params: old.merge(choice_id: "invalid")
    follow_redirect!
    expect(response.body).to include("あなたの回答：#{Choice.find(old[:choice_id]).body}")
    start_quiz
    fresh = form_data
    post answer_quiz_path, params: old
    expect(response).to redirect_to(quiz_path)
    follow_redirect!
    expect(form_data[:attempt_token]).to eq(fresh[:attempt_token])
    expect(form_data[:position]).to eq("1")
  end

  it "expires after two hours and clears guest progress on login" do
    start_quiz
    travel 2.hours + 1.second do
      get quiz_path
      expect(response).to redirect_to(new_quiz_path)
    end
    start_quiz
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: user.password } }
    get quiz_path
    expect(response).to redirect_to(new_quiz_path)
    expect(QuizRun.count).to eq(0)
  end

  it "stores member answers once, ignores forged correctness, and marks a finished run" do
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: user.password } }
    start_quiz
    5.times do |index|
      data = form_data
      post answer_quiz_path, params: data.merge(is_correct: false)
      expect { post answer_quiz_path, params: data }.not_to change(Answer, :count)
      get quiz_path(position: index + 2) unless index == 4
    end
    run = user.quiz_runs.sole
    expect(run.answers.count).to eq(5)
    expect(run.reload.completed_at).to be_present
    get result_quiz_path
    expect(response.body).to include("#{run.answers.count(&:correct?)}問")
    delete session_path
    another = create(:user)
    post session_path, params: { user: { email: another.email, password: another.password } }
    get quiz_path(run_id: run.id)
    expect(response).to redirect_to(new_quiz_path)
    expect(run.reload.answers.count).to eq(5)
  end

  it "keeps the exact question versions for an already started attempt" do
    start_quiz
    data = form_data
    question = Choice.find(data[:choice_id]).question
    question.retire!
    post answer_quiz_path, params: data
    follow_redirect!
    expect(response.body).to include(question.explanation)
  end
end
