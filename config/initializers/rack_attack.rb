# frozen_string_literal: true

class Rack::Attack
  ### Configure Cache ###

  # Use Rails cache (memory store in development, Redis/solid_cache in production)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Configuration ###

  # Throttle search requests by IP address
  # Allow 20 requests per minute
  throttle("search/ip", limit: 20, period: 1.minute) do |req|
    if req.path =~ /^\/api\/v1\/search/ && req.get?
      req.ip
    end
  end

  # Throttle search requests by authenticated user
  # Allow 60 requests per minute for authenticated users (more generous)
  throttle("search/user", limit: 60, period: 1.minute) do |req|
    if req.path =~ /^\/api\/v1\/search/ && req.get?
      # Extract user ID from session/auth (adjust based on your auth mechanism)
      if req.env["warden"]&.user
        req.env["warden"].user.id
      end
    end
  end

  # Throttle suggest endpoint separately (lighter weight)
  # Allow 30 requests per minute by IP
  throttle("suggest/ip", limit: 30, period: 1.minute) do |req|
    if req.path == "/api/v1/search/suggest" && req.get?
      req.ip
    end
  end

  ### Response Configuration ###

  # Customize throttled response
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "Content-Type" => "application/json",
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => (now + (match_data[:period] - (now % match_data[:period]))).to_s
    }

    [429, headers, [{
      error: {
        code: "rate_limit_exceeded",
        message: "Rate limit exceeded. Try again in #{match_data[:period]} seconds."
      }
    }.to_json]]
  end

  ### Logging ###

  ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
    req = payload[:request]
    if [:throttle].include? payload[:request].env["rack.attack.match_type"]
      Rails.logger.warn(
        "Rack::Attack: #{name} - IP: #{req.ip}, Path: #{req.path}, " \
        "Throttle: #{req.env['rack.attack.matched']}"
      )
    end
  end
end
