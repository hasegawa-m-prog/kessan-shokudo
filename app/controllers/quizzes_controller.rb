class QuizzesController < ApplicationController
  before_action :load_attempt, only: %i[show answer result]
  rescue_from QuizAttempt::Expired, with: :expired
  rescue_from QuizAttempt::StaleForm do
    redirect_to quiz_path, alert: "以前の学習画面からは回答できません。現在の問題を確認してください。", status: :see_other
  end

  def new
    @industries = Industry.order(:id)
  end

  def create
    industry = Industry.find_by(id: params[:industry_id]) unless params[:industry_id] == "random"
    unless industry || params[:industry_id] == "random"
      redirect_to new_quiz_path, alert: "学びたい業種を選んでください。"
      return
    end
    QuizAttempt.start(session: session, user: current_user, industry: industry)
    redirect_to quiz_path(position: 1), status: :see_other
  rescue QuestionPicker::NotEnoughQuestions => error
    redirect_to new_quiz_path, alert: error.message, status: :see_other
  end

  def show
    @position = Integer(params[:position] || @attempt.selected_ids.size + 1, exception: false)
    if @attempt.completed? && params[:position].nil?
      redirect_to result_quiz_path
    elsif !@position || !@position.between?(1, [ @attempt.selected_ids.size + 1, 5 ].min)
      redirect_to quiz_path, alert: "表示されている問題から順番に進めてください。"
    else
      prepare_question
    end
  end

  def answer
    @position = Integer(params[:position], exception: false)
    raise QuizAttempt::InvalidAnswer, "表示されている問題に回答してください。" unless @position
    @attempt.answer!(position: @position, choice_id: params[:choice_id], token: params[:attempt_token])
    redirect_to quiz_path(position: @position), status: :see_other
  rescue QuizAttempt::InvalidAnswer => error
    if @position == @attempt.selected_ids.size + 1 && @position <= 5
      prepare_question
      flash.now[:alert] = error.message
      render :show, status: :unprocessable_content
    else
      redirect_to quiz_path, alert: error.message, status: :see_other
    end
  end

  def result
    unless @attempt.completed?
      redirect_to quiz_path, alert: "5問に回答してから結果を確認できます。"
      return
    end
    ActiveRecord::Associations::Preloader.new(records: @attempt.questions, associations: :choices).call
  end

  private

  def load_attempt
    @attempt = QuizAttempt.new(session: session, user: current_user)
  end

  def prepare_question
    @question = @attempt.question_with_choices(@position - 1)
    @selected_choice = @attempt.selected_choice(@position - 1)
    sheets = @question.balance_sheets
    sheets = sheets.limit(1) if @question.kind == "transaction" && !@selected_choice
    @sheets = sheets.includes(balance_sheet_items: :account).to_a
    @visible_sheets = @sheets
    @maximum = @visible_sheets.map { |sheet| sheet.total("asset") }.max
  end

  def expired
    session.delete(:quiz)
    redirect_to new_quiz_path, alert: "学習の有効時間が過ぎたか、別の学習を開始しました。業種を選んで始めてください。", status: :see_other
  end
end
