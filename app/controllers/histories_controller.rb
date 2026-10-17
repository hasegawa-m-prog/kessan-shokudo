class HistoriesController < ApplicationController
  before_action :require_login

  def index
    @page = [ params[:page].to_i, 1 ].max
    @answers = current_user.answers.includes(:choice, quiz_run_question: [ :quiz_run, { question: :industry } ])
      .reorder(answered_at: :desc, id: :desc).limit(21).offset((@page - 1) * 20).to_a
    @has_next = @answers.size > 20
    @answers = @answers.first(20)
  end

  def show
    @answer = current_user.answers.includes(:choice, quiz_run_question: { question: [ :choices, { balance_sheets: { balance_sheet_items: :account } } ] }).find(params[:id])
    @question = @answer.quiz_run_question.question
    @selected_choice = @answer.choice
    @visible_sheets = @sheets = @question.balance_sheets.to_a
    @maximum = @sheets.map { |sheet| sheet.total("asset") }.max
    @can_review = current_user.answers.reviewable.exists?(@answer.id)
  end
end
