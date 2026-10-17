require "rails_helper"
require Rails.root.join("lib/demo_learning_content")

RSpec.describe "Quiz start confirmation and authentication continuity", type: :request do
  before { DemoLearningContent.load! }

  it "confirms the chosen industry without starting or replacing an attempt" do
    post quiz_path, params: { industry_id: Industry.first.id }
    get quiz_path
    token = Nokogiri::HTML(response.body).at_css('input[name="attempt_token"]')["value"]
    get confirmation_quiz_path(industry_id: Industry.last.id)
    expect(response.body).to include("クイズを始めますか？", Industry.last.name, "ゲストで5問を始める", "ログインして始める")
    expect(QuizRun.count).to eq(0)
    get quiz_path
    expect(Nokogiri::HTML(response.body).at_css('input[name="attempt_token"]')["value"]).to eq(token)
    get new_quiz_path(industry_id: "random")
    expect(Nokogiri::HTML(response.body).at_css('input[checked]')["value"]).to eq("random")
  end

  it "rejects missing, malformed and unknown industry selections" do
    [ nil, "invalid", "#{Industry.first.id}oops", "999999999", { url: "https://example.com" } ].each do |value|
      get confirmation_quiz_path, params: { industry_id: value }
      expect(response).to redirect_to(new_quiz_path)
    end
  end

  it "keeps in-progress guest cookies issued before the flow update usable" do
    state = {}
    original = QuizAttempt.start(session: state, user: nil, industry: Industry.first)
    state[:quiz].delete("industry_id")
    restored = QuizAttempt.new(session: state, user: nil)
    expect(restored.token).to eq(original.token)
    expect(restored.industry_key).to eq(Industry.first.id.to_s)
    expect(restored.questions.map(&:id)).to eq(original.questions.map(&:id))
  end

  it "preserves the industry through failed registration and login, but not guest answers" do
    industry = Industry.last
    post quiz_path, params: { industry_id: industry.id }
    get quiz_path
    html = Nokogiri::HTML(response.body)
    data = %w[position attempt_token choice_id].to_h { |key| [ key, html.at_css("input[name='#{key}']")["value"] ] }
    post answer_quiz_path, params: data
    get login_path(quiz_industry: industry.id)
    expect(response.body).to include("#{industry.name}を選択中")
    get signup_path(quiz_industry: industry.id)
    post registrations_path, params: { quiz_industry: industry.id, user: attributes_for(:user, password: "short") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML(response.body).at_css('input[name="quiz_industry"]')["value"]).to eq(industry.id.to_s)
    credentials = attributes_for(:user)
    post registrations_path, params: { quiz_industry: industry.id, user: credentials }
    expect(response).to redirect_to(login_path(quiz_industry: industry.id))
    follow_redirect!
    post session_path, params: { quiz_industry: industry.id, user: credentials.merge(password: "incorrect-password") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("#{industry.name}を選択中")
    post session_path, params: { quiz_industry: industry.id, user: credentials }
    expect(response).to redirect_to(confirmation_quiz_path(industry_id: industry.id))
    follow_redirect!
    expect(response.body).to include("ログイン中です", "5問のクイズを始める")
    expect(response.body).not_to include("ゲストで5問を始める")
    get quiz_path
    expect(response).to redirect_to(new_quiz_path)
    expect(Answer.count).to eq(0)
    expect(QuizRun.count).to eq(0)
  end

  it "accepts random selection but never redirects to a supplied external URL" do
    user = create(:user)
    post session_path, params: { quiz_industry: "random", user: { email: user.email, password: user.password } }
    expect(response).to redirect_to(confirmation_quiz_path(industry_id: "random"))
    get login_path(quiz_industry: Industry.first.id)
    expect(response).to redirect_to(confirmation_quiz_path(industry_id: Industry.first.id))
    get signup_path(quiz_industry: "random")
    expect(response).to redirect_to(confirmation_quiz_path(industry_id: "random"))
    delete session_path
    post session_path, params: { quiz_industry: "https://example.com", return_to: "https://example.com", user: { email: user.email, password: user.password } }
    expect(response).to redirect_to(root_path)
  end

  it "offers a retry of the same selection for guest and member results" do
    [ Industry.first.id.to_s, "random" ].each do |selection|
      post quiz_path, params: { industry_id: selection }
      5.times do |index|
        get quiz_path(position: index + 1)
        html = Nokogiri::HTML(response.body)
        data = %w[position attempt_token choice_id].to_h { |key| [ key, html.at_css("input[name='#{key}']")["value"] ] }
        post answer_quiz_path, params: data
      end
      get result_quiz_path
      html = Nokogiri::HTML(response.body)
      retry_link = html.css("a").find { |link| link.text == "同じ業種に再挑戦" }
      expect(retry_link["href"]).to eq(confirmation_quiz_path(industry_id: selection))
      expect(response.body).to include("別の業種を選ぶ")
      user = create(:user)
      post session_path, params: { user: { email: user.email, password: user.password } }
    end
  end
end
