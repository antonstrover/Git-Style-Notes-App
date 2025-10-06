# frozen_string_literal: true

module ApiErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
  end

  private

  def handle_not_found(exception)
    render json: {
      error: {
        code: 'not_found',
        message: exception.message
      }
    }, status: :not_found
  end

  def handle_validation_error(exception)
    render json: {
      error: {
        code: 'validation_failed',
        message: 'Validation failed',
        details: exception.record.errors.as_json
      }
    }, status: :unprocessable_entity
  end

  def handle_forbidden(_exception)
    render json: {
      error: {
        code: 'forbidden',
        message: 'You are not authorized to perform this action'
      }
    }, status: :forbidden
  end
end
