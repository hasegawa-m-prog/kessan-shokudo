require "rails_helper"

RSpec.describe "Account access", type: :request do
  it "renders the home page with working registration and login links" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("決算食堂", 'href="/signup"', 'href="/login"', "準備中")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "renders the registration form" do
    get signup_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("確認用パスワード")
  end

  it "registers a user then directs them to login" do
    expect { post registrations_path, params: { user: attributes_for(:user) } }.to change(User, :count).by(1)
    expect(response).to redirect_to(login_path)
    follow_redirect!
    expect(response.body).to include("登録が完了しました")
  end

  it "does not register invalid data and explains the errors" do
    expect { post registrations_path, params: { user: { email: "invalid", password: "short", password_confirmation: "different" } } }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("入力内容をご確認ください", "メールアドレス")
    expect(response.body).not_to include('value="short"')
  end

  it "does not register duplicate addresses" do
    user = create(:user)
    expect { post registrations_path, params: { user: attributes_for(:user, email: user.email.upcase) } }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "persists login across requests and clears it on logout" do
    user = create(:user)
    post session_path, params: { user: { email: " #{user.email.upcase} ", password: user.password } }
    expect(response).to redirect_to(root_path)
    get root_path
    expect(response.body).to include("ログイン中", "ログアウト")
    get signup_path
    expect(response).to redirect_to(root_path)
    get login_path
    expect(response).to redirect_to(root_path)
    expect { delete session_path }.not_to change(User, :count)
    expect(response).to redirect_to(root_path)
    get root_path
    expect(response.body).not_to include("ログイン中")
    post session_path, params: { user: { email: user.email, password: user.password } }
    expect(response).to redirect_to(root_path)
  end

  it "uses the same error for unknown email and incorrect password" do
    user = create(:user)
    [ user.email, "unknown@example.com" ].each do |email|
      post session_path, params: { user: { email: email, password: "incorrect-password" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("メールアドレスまたはパスワードが正しくありません")
      get root_path
      expect(response.body).not_to include("ログイン中")
    end
  end

  it "returns a bad request for a malformed payload" do
    post registrations_path, params: { unrelated: "value" }
    expect(response).to have_http_status(:bad_request)
  end

  it "rejects missing CSRF tokens when protection is enabled" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    expect { post registrations_path, params: { user: attributes_for(:user) } }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
