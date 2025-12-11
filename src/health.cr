# Health check endpoint for Pasto application
module Pasto
  # Health check endpoint - returns service status
  get "/health" do |env|
    env.response.content_type = "text/plain"
    env.response.status_code = 200
    "OK"
  end
end
