class ReviewsController < ApplicationController
  before_action :require_login
  before_action :load_attempt, only: %i[show answer]
  rescue_from QuizAttempt::Expired, with: :expired
  rescue_from QuizAttempt::StaleForm do
    redirect_to review_path, alert: "以前の復習画面からは回答できません。現在の問題を確認してください。", status: :see_other
  end

  def index
    @page = [ params[:page].to_i, 1 ].max
    latest_ids = current_user.answers.reviewable.reorder(nil).select("MAX(answers.id)").group("quiz_run_questions.question_id")
    @answers = current_user.answers.where(id: latest_ids).includes(quiz_run_question: { question: :industry })
      .reorder(answered_at: :desc, id: :desc).limit(21).offset((@page - 1) * 20).to_a
    @has_next = @answers.size > 20
    @answers = @answers.first(20)
  end

  def create
    QuizAttempt.start_review(session: session, user: current_user, answer_id: params[:answer_id])
    redirect_to review_path, status: :see_other
  end

  def show
    prepare_question
  end

  def answer
    @attempt.answer!(position: 1, choice_id: params[:choice_id], token: params[:attempt_token])
    redirect_to review_path, status: :see_other
  rescue QuizAttempt::InvalidAnswer => error
    prepare_question
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_content
  end

  private

  def load_attempt
    @attempt = QuizAttempt.new(session: session, user: current_user, kind: "review")
  end

  def prepare_question
    @question = @attempt.question_with_choices(0)
    @selected_choice = @attempt.selected_choice(0)
    sheets = @question.balance_sheets
    sheets = sheets.limit(1) if @question.kind == "transaction" && !@selected_choice
    @sheets = sheets.includes(balance_sheet_items: :account).to_a
    @visible_sheets = @sheets
    @maximum = @visible_sheets.map { |sheet| sheet.total("asset") }.max
  end

  def expired
    session.delete(:review)
    redirect_to reviews_path, alert: "復習を始める問題を選んでください。有効時間は開始から2時間です。", status: :see_other
  end
end
