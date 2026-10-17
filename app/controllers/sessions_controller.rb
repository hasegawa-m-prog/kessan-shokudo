class SessionsController < ApplicationController
  before_action :load_quiz_selection, only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path(quiz_industry: @quiz_selection&.key), alert: "試行回数が多いため、3分ほどお待ちください。" }

  def new
    redirect_to after_login_path if current_user
  end

  def create
    credentials = params.expect(user: [ :email, :password ])
    user = User.authenticate_by(email: credentials[:email].to_s.strip.downcase, password: credentials[:password])
    if user
      reset_session
      session[:user_id] = user.id
      redirect_to after_login_path, notice: "ログインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません。"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました。", status: :see_other
  end

  private

  def load_quiz_selection
    @quiz_selection = QuizSelection.find(params[:quiz_industry])
  end

  def after_login_path
    @quiz_selection ? confirmation_quiz_path(industry_id: @quiz_selection.key) : root_path
  end
end
