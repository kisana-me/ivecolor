class ApplicationController < ActionController::Base
  include ErrorManagement
  include SessionManagement
  include TurnstileManagement
  include Pagination

  before_action :current_account

  helper_method :admin?

  def routing_error
    raise ActionController::RoutingError, params[:path]
  end

  private

  def require_signin
    return if @current_account

    store_location
    flash[:alert] = "サインインしてください"
    redirect_to root_path
  end

  def require_signout
    return unless @current_account

    flash[:alert] = "サインイン済みです"
    redirect_to root_path
  end

  def require_admin
    render_404 unless admin?
  end

  def admin?
    @current_account&.admin?
  end

  def store_location
    session[:forwarding_url] = request.original_url if request.get?
  end

  def redirect_back_or(default = root_path, **)
    redirect_to(session.delete(:forwarding_url) || default, **)
  end
end
