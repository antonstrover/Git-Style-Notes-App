class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_user!

  # Pundit error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    render json: {
      error: {
        code: "forbidden",
        message: "You are not authorized to perform this action"
      }
    }, status: :forbidden
  end
end
