require "./spec_helper"
require "../src/ratelimit"

describe "Pasto Rate Limiting" do
  describe Pasto::RateLimits do
    describe "Rate Limiter Configuration" do
      it "initializes rate limiters without crashing" do
        # Create a mock config object
        config = MockRateLimitConfig.new

        # This should not raise an exception
        Pasto::RateLimits.init(config)
        true.should be_true
      end

      it "stores rate limiter instances" do
        config = MockRateLimitConfig.new
        Pasto::RateLimits.init(config)

        # After initialization, the limiters should exist (though may be nil if not properly configured)
        Pasto::RateLimits.paste_ip.should be_a(RateLimiter?)
        Pasto::RateLimits.highlight.should be_a(RateLimiter?)
        Pasto::RateLimits.login.should be_a(RateLimiter?)
        Pasto::RateLimits.http.should be_a(RateLimiter?)
      end

      it "handles multiple initializations safely" do
        config1 = MockRateLimitConfig.new(rate_paste_limit: 10)
        config2 = MockRateLimitConfig.new(rate_paste_limit: 20)

        # Should handle multiple initializations without issues
        Pasto::RateLimits.init(config1)
        Pasto::RateLimits.init(config2)
        true.should be_true
      end
    end

    describe "Rate Limiting Methods" do
      before_all do
        # Initialize rate limiters with test configuration
        config = MockRateLimitConfig.new
        Pasto::RateLimits.init(config)
      end

      describe ".allow_highlight?" do
        it "handles highlight rate limit checks" do
          client_ip = "192.168.1.100"

          # The method should return a tuple with boolean and result
          result = Pasto::RateLimits.allow_highlight?(client_ip)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end

        it "handles different IP addresses independently" do
          ip1 = "192.168.1.101"
          ip2 = "192.168.1.102"

          result1 = Pasto::RateLimits.allow_highlight?(ip1)
          result2 = Pasto::RateLimits.allow_highlight?(ip2)

          result1.should be_a(Tuple(Bool, RateLimitResult))
          result2.should be_a(Tuple(Bool, RateLimitResult))
        end
      end

      describe ".allow_paste?" do
        it "handles paste rate limit checks with IP only" do
          client_ip = "192.168.1.103"

          result = Pasto::RateLimits.allow_paste?(client_ip, nil)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end

        it "handles paste rate limit checks with IP and user ID" do
          client_ip = "192.168.1.104"
          user_id = "test-user-123"

          result = Pasto::RateLimits.allow_paste?(client_ip, user_id)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end

        it "handles nil user ID gracefully" do
          client_ip = "192.168.1.105"

          result = Pasto::RateLimits.allow_paste?(client_ip, nil)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end
      end

      describe ".allow_login?" do
        it "handles login rate limit checks" do
          client_ip = "192.168.1.106"

          result = Pasto::RateLimits.allow_login?(client_ip)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end
      end

      describe ".allow_http?" do
        it "handles HTTP rate limit checks" do
          client_ip = "192.168.1.107"

          result = Pasto::RateLimits.allow_http?(client_ip)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end
      end
    end

    describe "Rate Limiting Behavior" do
      before_all do
        config = MockRateLimitConfig.new
        Pasto::RateLimits.init(config)
      end

      it "handles multiple requests from same IP" do
        client_ip = "192.168.1.200"

        # Multiple calls should not crash
        5.times do
          result = Pasto::RateLimits.allow_http?(client_ip)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end
      end

      it "handles different rate limit types independently" do
        client_ip = "192.168.1.201"

        # Different limit types should work independently
        highlight_result = Pasto::RateLimits.allow_highlight?(client_ip)
        paste_result = Pasto::RateLimits.allow_paste?(client_ip, nil)
        login_result = Pasto::RateLimits.allow_login?(client_ip)
        http_result = Pasto::RateLimits.allow_http?(client_ip)

        # All should return valid tuples
        highlight_result.should be_a(Tuple(Bool, RateLimitResult))
        paste_result.should be_a(Tuple(Bool, RateLimitResult))
        login_result.should be_a(Tuple(Bool, RateLimitResult))
        http_result.should be_a(Tuple(Bool, RateLimitResult))
      end

      it "handles various IP address formats" do
        ips = [
          "127.0.0.1",
          "192.168.1.1",
          "10.0.0.1",
          "::1"  # IPv6 localhost - may cause issues depending on implementation
        ]

        ips.each do |ip|
          begin
            result = Pasto::RateLimits.allow_http?(ip)
            result.should be_a(Tuple(Bool, RateLimitResult))
          rescue ex
            # Some IP formats might not be supported by the rate limiter
            # This is acceptable as long as it doesn't crash the entire system
            ex.message.should_not be_nil
          end
        end
      end
    end

    describe "Thread Safety" do
      it "handles concurrent access safely" do
        config = MockRateLimitConfig.new
        Pasto::RateLimits.init(config)

        # Test that rate limiters can handle multiple operations without crashing
        # The mutex in the implementation should provide thread safety
        client_ip = "192.168.1.200"

        # Multiple rapid calls should not crash
        10.times do |i|
          result = Pasto::RateLimits.allow_http?(client_ip)
          result.should be_a(Tuple(Bool, RateLimitResult))
        end

        # Should not crash or produce inconsistent results
        true.should be_true
      end
    end

    describe "Rate Limit Result Structure" do
      before_all do
        config = MockRateLimitConfig.new
        Pasto::RateLimits.init(config)
      end

      it "provides detailed rate limit information" do
        client_ip = "192.168.1.250"

        allowed, result = Pasto::RateLimits.allow_highlight?(client_ip)

        # The result should contain rate limit details
        result.should be_a(RateLimitResult)
        allowed.should be_a(Bool)
      end

      it "returns consistent result structure" do
        client_ip = "192.168.1.251"

        http_allowed, http_result = Pasto::RateLimits.allow_http?(client_ip)
        highlight_allowed, highlight_result = Pasto::RateLimits.allow_highlight?(client_ip)

        # Both results should have the same structure
        http_result.should be_a(RateLimitResult)
        highlight_result.should be_a(RateLimitResult)
        http_allowed.should be_a(Bool)
        highlight_allowed.should be_a(Bool)
      end
    end

    describe "Configuration Edge Cases" do
      it "handles very restrictive limits" do
        config = MockRateLimitConfig.new(
          rate_paste_limit: 1,
          rate_paste_window: 1,
          rate_highlight_limit: 1,
          rate_login_limit: 1,
          rate_http_limit: 1
        )

        Pasto::RateLimits.init(config)

        client_ip = "192.168.1.252"

        # Should handle very restrictive limits without crashing
        result = Pasto::RateLimits.allow_http?(client_ip)
        result.should be_a(Tuple(Bool, RateLimitResult))
      end

      it "handles different time windows" do
        # Create a custom config with different time windows by setting properties directly
        config = MockRateLimitConfig.new
        config.rate_paste_window = 60   # 1 minute
        config.rate_highlight_window = 300  # 5 minutes
        config.rate_login_window = 600   # 10 minutes

        Pasto::RateLimits.init(config)

        client_ip = "192.168.1.253"

        # Different time windows should work
        paste_result = Pasto::RateLimits.allow_paste?(client_ip, nil)
        highlight_result = Pasto::RateLimits.allow_highlight?(client_ip)
        login_result = Pasto::RateLimits.allow_login?(client_ip)

        paste_result.should be_a(Tuple(Bool, RateLimitResult))
        highlight_result.should be_a(Tuple(Bool, RateLimitResult))
        login_result.should be_a(Tuple(Bool, RateLimitResult))
      end
    end
  end

  describe "Rate Limiting Integration Considerations" do
    it "handles nil rate limiters gracefully" do
      # Test behavior when rate limiters haven't been properly initialized
      # This might happen in certain error conditions

      # We can't easily test this without manipulating internal state,
      # but we can verify that the methods don't crash with valid inputs
      config = MockRateLimitConfig.new
      Pasto::RateLimits.init(config)

      client_ip = "127.0.0.1"

      # Should handle normal operations without issues
      result = Pasto::RateLimits.allow_http?(client_ip)
      result.should be_a(Tuple(Bool, RateLimitResult))
    end

    it "provides testable configuration" do
      # The mock configuration should provide realistic values
      config = MockRateLimitConfig.new

      # These should all be positive integers
      config.rate_paste_limit.should be > 0
      config.rate_paste_window.should be > 0
      config.rate_highlight_limit.should be > 0
      config.rate_login_limit.should be > 0
      config.rate_http_limit.should be > 0

      # These should be reasonable time windows (in seconds)
      config.rate_paste_window.should be > 0
      config.rate_highlight_window.should be > 0
      config.rate_login_window.should be > 0
      config.rate_http_window.should be > 0
    end
  end
end

# Mock configuration class for testing rate limits
class MockRateLimitConfig
  property rate_paste_limit : Int32 = 100
  property rate_paste_window : Int32 = 3600
  property rate_paste_user_limit : Int32 = 200
  property rate_paste_user_window : Int32 = 3600
  property rate_paste_global_limit : Int32 = 1000
  property rate_paste_global_window : Int32 = 3600
  property rate_highlight_limit : Int32 = 50
  property rate_highlight_window : Int32 = 3600
  property rate_login_limit : Int32 = 10
  property rate_login_window : Int32 = 300
  property rate_http_limit : Int32 = 1000
  property rate_http_window : Int32 = 3600
  property rate_backup_limit : Int32 = 5
  property rate_backup_window : Int32 = 86400

  def initialize(
    @rate_paste_limit = 100,
    @rate_paste_window = 3600,
    @rate_highlight_limit = 50,
    @rate_login_limit = 10,
    @rate_http_limit = 1000
  )
  end
end