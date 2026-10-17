class RegistrationsController < ApplicationController
  before_action :load_quiz_selection
  before_action :redirect_signed_in_user
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_to signup_path(quiz_industry: @quiz_selection&.key), alert: "少し時間をおいてからお試しください。" }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: [ :email, :password, :password_confirmation ]))
    if @user.save
      reset_session
      redirect_to login_path(quiz_industry: @quiz_selection&.key), notice: "登録が完了しました。ログインしてください。"
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:email, :taken)
    render :new, status: :unprocessable_content
  end

  private

  def load_quiz_selection
    @quiz_selection = QuizSelection.find(params[:quiz_industry])
  end

  def redirect_signed_in_user
    redirect_to(@quiz_selection ? confirmation_quiz_path(industry_id: @quiz_selection.key) : root_path) if current_user
  end
end
