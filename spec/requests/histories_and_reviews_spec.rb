require "rails_helper"
require Rails.root.join("lib/demo_learning_content")

RSpec.describe "Private history and one-question review", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  before { DemoLearningContent.load! }
  let(:user) { create(:user) }

  def sign_in(member = user)
    post session_path, params: { user: { email: member.email, password: member.password } }
  end

  def recorded_answer(member = user, correct: false)
    attempt = QuizAttempt.start(session: {}, user: member, industry: Industry.first)
    choice = attempt.questions.first.choices.find { |candidate| candidate.is_correct == correct }
    attempt.answer!(position: 1, choice_id: choice.id, token: attempt.token)
    member.answers.order(:id).last
  end

  def review_data
    html = Nokogiri::HTML(response.body)
    { attempt_token: html.at_css('input[name="attempt_token"]')["value"], choice_id: html.at_css('input[name="choice_id"]')["value"] }
  end

  it "requires login for all history and review operations" do
    [ histories_path, history_path(1), quiz_run_path(1), reviews_path, review_path ].each do |url|
      get url
      expect(response).to redirect_to(login_path)
    end
    expect { post review_path, params: { answer_id: 1 } }.not_to change(QuizRun, :count)
    expect(response).to redirect_to(login_path)
    post answer_review_path, params: { choice_id: 1 }
    expect(response).to redirect_to(login_path)
  end

  it "explains empty history and review lists" do
    sign_in
    get histories_path
    expect(response.body).to include("回答履歴はありません")
    get reviews_path
    expect(response.body).to include("復習する問題はありません")
  end

  it "shows personal history after re-login with question, selected choice, result and date" do
    answer = recorded_answer
    sign_in
    delete session_path
    sign_in
    get histories_path
    expect(response.body).to include("5問クイズ", "1問回答済み", "未完了")
    get quiz_run_path(answer.quiz_run_question.quiz_run_id)
    expect(response.body).to include(answer.choice.body, "× 不正解", answer.answered_at.in_time_zone("Tokyo").strftime("%Y年%m月%d日 %H:%M"))
    expect(Nokogiri::HTML(response.body).css('.run-question-list > li').size).to eq(5)
    expect(response.body).to include("2問目：未回答")
    get history_path(answer)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(answer.quiz_run_question.question.body, "問題の版：#{DemoLearningContent::VERSION}", "この問題を復習する")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "does not expose or review another user's history by changing an id" do
    foreign = recorded_answer(create(:user))
    sign_in
    get histories_path(user_id: foreign.quiz_run_question.quiz_run.user_id)
    expect(response.body).to include("回答履歴はありません")
    get history_path(foreign)
    expect(response).to have_http_status(:not_found)
    get quiz_run_path(foreign.quiz_run_question.quiz_run_id)
    expect(response).to have_http_status(:not_found)
    expect { post review_path, params: { answer_id: foreign.id } }.not_to change(QuizRun, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "retains a retired version in history but excludes it from new review" do
    answer = recorded_answer
    answer.quiz_run_question.question.retire!
    sign_in
    get history_path(answer)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("この版は出題を終了しています", answer.choice.body)
    expect(response.body).not_to include("この問題を復習する")
    get reviews_path
    expect(response.body).to include("復習する問題はありません")
    expect { post review_path, params: { answer_id: answer.id } }.not_to change(QuizRun, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "does not start a review from a correct answer" do
    answer = recorded_answer(correct: true)
    sign_in
    get reviews_path
    expect(response.body).to include("復習する問題はありません")
    post review_path, params: { answer_id: answer.id }
    expect(response).to have_http_status(:not_found)
  end

  it "saves a separate review answer exactly once and leaves the original incorrect answer intact" do
    original = recorded_answer
    question = original.quiz_run_question.question
    sign_in
    get reviews_path
    expect(response.body).to include(question.title)
    post review_path, params: { answer_id: original.id }
    follow_redirect!
    expect(response.body).not_to include(question.explanation)
    data = review_data.merge(choice_id: question.correct_choice.id)
    expect { post answer_review_path, params: data }.to change(Answer, :count).by(1)
    follow_redirect!
    expect(response.body).to include("○ 正解です", question.explanation, "元の回答も履歴に残っています")
    expect { post answer_review_path, params: data }.not_to change(Answer, :count)
    expect(original.reload).not_to be_correct
    run = user.quiz_runs.where(kind: "review").sole
    expect(run.quiz_run_questions.count).to eq(1)
    expect(run.completed_at).to be_present
    expect(run.answers.sole).to be_correct
    get histories_path
    expect(response.body).to include("クイズ", "復習", "5問中 0問正解", "1問中 1問正解")
    expect(Nokogiri::HTML(response.body).css('.history-list > li').size).to eq(2)
    get quiz_run_path(run)
    expect(response.body).to include("○ 正解", question.title)
    get reviews_path
    expect(Nokogiri::HTML(response.body).css('input[name="answer_id"]').size).to eq(1)
  end

  it "rejects invalid review answers and protects a newly started review from an older form" do
    original = recorded_answer
    sign_in
    post review_path, params: { answer_id: original.id }
    follow_redirect!
    old = review_data
    post answer_review_path, params: old.merge(choice_id: "invalid")
    expect(response).to have_http_status(:unprocessable_content)
    post review_path, params: { answer_id: original.id }
    follow_redirect!
    fresh = review_data
    expect { post answer_review_path, params: old }.not_to change(Answer, :count)
    follow_redirect!
    expect(review_data[:attempt_token]).to eq(fresh[:attempt_token])
  end

  it "expires a review and removes access when logging out" do
    original = recorded_answer
    sign_in
    post review_path, params: { answer_id: original.id }
    travel 2.hours + 1.second do
      get review_path
      expect(response).to redirect_to(reviews_path)
    end
    delete session_path
    get review_path
    expect(response).to redirect_to(login_path)
  end

  it "paginates learning runs without dropping or repeating them" do
    21.times { recorded_answer }
    sign_in
    get histories_path
    first_ids = Nokogiri::HTML(response.body).css('.history-list h2 a').map { |link| link["href"] }
    expect(first_ids.size).to eq(20)
    expect(first_ids).to eq(user.quiz_runs.order(started_at: :desc, id: :desc).limit(20).map { |run| quiz_run_path(run) })
    expect(response.body).to include("次の20件")
    get histories_path(page: 2)
    last_ids = Nokogiri::HTML(response.body).css('.history-list h2 a').map { |link| link["href"] }
    expect(last_ids.size).to eq(1)
    expect(first_ids & last_ids).to be_empty
  end

  it "groups five answers into one completed run and excludes runs without answers" do
    empty = QuizAttempt.start(session: {}, user: user, industry: Industry.first)
    attempt = QuizAttempt.start(session: {}, user: user, industry: nil)
    attempt.questions.each_with_index do |question, index|
      attempt.answer!(position: index + 1, choice_id: question.correct_choice.id, token: attempt.token)
    end
    sign_in
    get histories_path
    expect(Nokogiri::HTML(response.body).css('.history-list > li').size).to eq(1)
    expect(response.body).to include("おまかせ", "5問中 5問正解", "5問回答済み")
    run = user.quiz_runs.where(industry_id: nil).sole
    get quiz_run_path(run)
    expect(Nokogiri::HTML(response.body).css('.run-question-list > li').size).to eq(5)
    expect(response.body).not_to include("未回答", "この問題を復習する")
    get quiz_run_path(user.quiz_runs.where(industry: Industry.first).sole)
    expect(response).to have_http_status(:not_found)
    expect(empty.selected_ids).to be_empty
  end
end
