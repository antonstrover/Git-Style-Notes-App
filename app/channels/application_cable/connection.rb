# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      Rails.logger.info "ActionCable connected: user_id=#{current_user.id}"
    end

    private

    def find_verified_user
      # Try token from query params first (sent by frontend)
      if token = request.params[:token]
        user = authenticate_with_token(token)
        return user if user
      end

      # Fallback to HTTP Basic Auth header
      if verified_user = authenticate_with_http_basic
        return verified_user
      end

      reject_unauthorized_connection
    end

    def authenticate_with_token(token)
      # Token is base64(email:password)
      decoded = Base64.decode64(token)
      email, password = decoded.split(":", 2)

      return nil unless email && password

      user = User.find_by(email: email)
      user if user&.valid_password?(password)
    rescue StandardError => e
      Rails.logger.warn "ActionCable auth token decode failed: #{e.message}"
      nil
    end

    def authenticate_with_http_basic
      authenticate_with_http_basic do |email, password|
        user = User.find_by(email: email)
        user if user&.valid_password?(password)
      end
    end
  end
end
