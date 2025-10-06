class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include Pundit::Authorization

  before_action :authenticate_user!

  # Pundit error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def authenticate_user!
    authenticate_with_http_basic do |email, password|
      @current_user = User.find_by(email: email)
      if @current_user&.valid_password?(password)
        @current_user
      else
        render_unauthorized
        nil
      end
    end || render_unauthorized
  end

  def current_user
    @current_user
  end

  def render_unauthorized
    headers['WWW-Authenticate'] = 'Basic realm="Application"'
    render json: {
      error: {
        code: "unauthorized",
        message: "Invalid credentials"
      }
    }, status: :unauthorized
  end

  def user_not_authorized
    render json: {
      error: {
        code: "forbidden",
        message: "You are not authorized to perform this action"
      }
    }, status: :forbidden
  end
end
