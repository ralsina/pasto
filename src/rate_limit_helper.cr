# Rate limiting helper module for Pasto application
module Pasto
  module RateLimitHelper
    # Check rate limits and handle exceeded limits with proper response
    def self.check_and_handle_rate_limit(env, rate_limit_type : Symbol, extra_args = nil, return_mode : Symbol = :next)
      client_ip = Pasto.get_client_ip(env)

      case rate_limit_type
      when :highlight
        allowed, result = Pasto::RateLimits.allow_highlight?(client_ip)
      when :paste
        user_id = extra_args
        allowed, result = Pasto::RateLimits.allow_paste?(client_ip, user_id)
      when :login
        allowed, result = Pasto::RateLimits.allow_login?(client_ip)
      when :http
        allowed, result = Pasto::RateLimits.allow_http?(client_ip)
      else
        raise "Unknown rate limit type: #{rate_limit_type}"
      end

      add_rate_limit_headers(env, result)

      unless allowed
        response = rate_limit_response(env, result, rate_limit_type, return_mode)
        return false, response
      end

      return true, nil
    end

    # Add rate limit headers to response
    private def self.add_rate_limit_headers(env, result)
      env.response.headers["X-RateLimit-Remaining"] = result.remaining.to_s
      env.response.headers["X-RateLimit-Reset"] = result.reset_time.to_unix.to_s
    end

    # Generate appropriate rate limit response based on request type
    private def self.rate_limit_response(env, result, rate_limit_type : Symbol, return_mode : Symbol = :next)
      retry_after = Math.max(1, (result.reset_time - Time.utc).total_seconds.ceil.to_i)
      env.response.status_code = 429
      env.response.headers["Retry-After"] = retry_after.to_s

      case rate_limit_type
      when :highlight
        env.response.content_type = "application/json"
        {"error" => "Rate limit exceeded. Retry after #{retry_after} seconds."}.to_json
      when :http
        env.response.content_type = "text/plain"
        "Too many requests. Please slow down. Retry after #{retry_after} seconds."
      when :paste, :login
        "Rate limit exceeded. Please wait #{retry_after} seconds."
      else
        "Rate limit exceeded. Retry after #{retry_after} seconds."
      end
    end
  end
end