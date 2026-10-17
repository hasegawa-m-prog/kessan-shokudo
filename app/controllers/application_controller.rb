class ApplicationController < ActionController::Base
  helper_method :current_user
  before_action :disable_private_caching
  allow_browser versions: :modern

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_login
    redirect_to login_path, alert: "履歴の確認にはログインが必要です。" unless current_user
  end

  def disable_private_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
