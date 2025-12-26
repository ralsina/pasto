module Pasto
  module TimeHelper
    # Converts a Time object to a human-friendly relative time string
    # Examples: "just now", "2 hours ago", "yesterday", "3 weeks ago"

    def self.relative_time(time : Time) : String
      now = Time.utc
      diff = (now - time).total_seconds

      case
      when diff < 60
        "just now"
      when diff < 3600
        minutes = (diff / 60).to_i
        "#{minutes} #{minutes == 1 ? "minute" : "minutes"} ago"
      when diff < 86400
        hours = (diff / 3600).to_i
        "#{hours} #{hours == 1 ? "hour" : "hours"} ago"
      when diff < 172800 # 2 days
        "yesterday"
      when diff < 604800 # 7 days
        days = (diff / 86400).to_i
        "#{days} days ago"
      when diff < 2592000 # 30 days
        weeks = (diff / 604800).to_i
        "#{weeks} #{weeks == 1 ? "week" : "weeks"} ago"
      when diff < 31536000 # 365 days
        months = (diff / 2592000).to_i
        "#{months} #{months == 1 ? "month" : "months"} ago"
      else
        years = (diff / 31536000).to_i
        "#{years} #{years == 1 ? "year" : "years"} ago"
      end
    end
  end
end
