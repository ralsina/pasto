# Help page endpoint for Pasto application
module Pasto
  get "/help" do |env|
    env.response.content_type = "text/html"
    current_user = Pasto.get_current_user(env)
    config = Pasto.config

    # Get all theme-related template variables
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, config)
    page_title = "Help & Usage Guide"
    is_home_page = false

    # Social media metadata (generic for non-paste pages)
    meta_title = "Pasto - Help & Usage Guide"
    meta_description = "Learn how to use Pasto, a modern pastebin with live syntax highlighting and SSH access"
    meta_url = ""
    meta_image = ""

    content = render "src/views/help.ecr"
    render "src/views/layout.ecr"
  end
end
