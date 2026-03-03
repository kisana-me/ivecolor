class SignupController < ApplicationController
  before_action :require_signout
  before_action :ensure_oauth_context

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)
    @account.meta["subscription"] = session[:oauth_signup]&.dig("subscription")

    if @account.save
      sign_in(@account)
      OauthAccount.create!(
        account: @account,
        provider: session[:oauth_signup]["provider"],
        uid: session[:oauth_signup]["uid"],
        access_token: session[:oauth_signup]["access_token"],
        refresh_token: session[:oauth_signup]["refresh_token"],
        expires_at: session[:oauth_signup]["expires_at"],
        fetched_at: session[:oauth_signup]["fetched_at"]
      )
      session.delete(:oauth_signup)
      redirect_back_or root_path, notice: "登録完了"
    else
      render :new
    end
  end

  private

  def ensure_oauth_context
    return if session[:oauth_signup].present?

    render plain: "不正なアクセス", status: :forbidden
  end

  def account_params
    params.expect(
      account: %i[
        name
        name_id
        description
        birthdate
        visibility
        password
        password_confirmation
      ]
    )
  end
end
