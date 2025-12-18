require "rate_limiter"

# Comprehensive rate limiting for the Pasto web server

# Comprehensive rate limiting for the Pasto web server
module Pasto
  class RateLimits
    # Individual limiters initialized from config
    class_property paste_ip : RateLimiter?
    class_property paste_user : RateLimiter?
    class_property paste_global : RateLimiter?
    class_property highlight : RateLimiter?
    class_property login : RateLimiter?
    class_property http : RateLimiter?

    @@mutex = Mutex.new

    def self.init(config)
      @@mutex.synchronize do
        @@paste_ip = RateLimiter.new(config.rate_paste_limit, config.rate_paste_window)
        @@paste_user = RateLimiter.new(config.rate_paste_user_limit, config.rate_paste_user_window)
        @@paste_global = RateLimiter.new(config.rate_paste_global_limit, config.rate_paste_global_window)
        @@highlight = RateLimiter.new(config.rate_highlight_limit, config.rate_highlight_window)
        @@login = RateLimiter.new(config.rate_login_limit, config.rate_login_window)
        @@http = RateLimiter.new(config.rate_http_limit, config.rate_http_window)
      end
    end

    # Check paste creation - returns {allowed, result} for headers
    def self.allow_paste?(ip : String, user_id : String?) : {Bool, RateLimitResult}
      @@mutex.synchronize do
        paste_global = @@paste_global
        paste_ip = @@paste_ip
        paste_user = @@paste_user

        # Return allowed if limiters not initialized (shouldn't happen)
        unless paste_global && paste_ip
          return {true, RateLimitResult.new(allowed: true, remaining: 0, reset_time: Time.utc, total_requests: 0)}
        end

        # Check global limit first
        global_result = paste_global.check("global")
        unless global_result.allowed?
          puts "⚠️  Rate limit hit: global paste limit (IP: #{ip})"
          return {false, global_result}
        end

        # Check IP limit
        ip_result = paste_ip.check(ip)
        unless ip_result.allowed?
          puts "⚠️  Rate limit hit: paste IP limit (IP: #{ip})"
          return {false, ip_result}
        end

        # Check user limit if logged in
        if user_id && paste_user
          user_result = paste_user.check(user_id)
          unless user_result.allowed?
            puts "⚠️  Rate limit hit: paste user limit (User: #{user_id})"
            return {false, user_result}
          end
          return {true, user_result}
        end

        {true, ip_result}
      end
    end

    # Check highlight API - returns {allowed, result}
    def self.allow_highlight?(ip : String) : {Bool, RateLimitResult}
      @@mutex.synchronize do
        if highlight = @@highlight
          result = highlight.check(ip)
          unless result.allowed?
            puts "⚠️  Rate limit hit: highlight limit (IP: #{ip})"
          end
          {result.allowed?, result}
        else
          {true, RateLimitResult.new(allowed: true, remaining: 0, reset_time: Time.utc, total_requests: 0)}
        end
      end
    end

    # Check login attempt - returns {allowed, result}
    def self.allow_login?(ip : String) : {Bool, RateLimitResult}
      @@mutex.synchronize do
        if login = @@login
          result = login.check(ip)
          unless result.allowed?
            puts "⚠️  Rate limit hit: login limit (IP: #{ip})"
          end
          {result.allowed?, result}
        else
          {true, RateLimitResult.new(allowed: true, remaining: 0, reset_time: Time.utc, total_requests: 0)}
        end
      end
    end

    # Check HTTP request (excludes highlight, cache, static) - returns {allowed, result}
    def self.allow_http?(ip : String) : {Bool, RateLimitResult}
      @@mutex.synchronize do
        if http = @@http
          result = http.check(ip)
          unless result.allowed?
            puts "⚠️  Rate limit hit: HTTP limit (IP: #{ip})"
          end
          {result.allowed?, result}
        else
          {true, RateLimitResult.new(allowed: true, remaining: 0, reset_time: Time.utc, total_requests: 0)}
        end
      end
    end
  end
end
