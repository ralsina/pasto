# Help page endpoint for Pasto application
module Pasto
  get "/help" do |env|
    env.response.content_type = "text/html"
    current_user = Pasto.get_current_user(env)
    config = Pasto.config

    # Get theme preferences with priority: user config > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || "auto"
    saved_pico_color = current_user.try(&.pico_color) || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || config.theme
    page_title = "Help & Usage Guide"
    is_home_page = false
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme
    theme = config.theme
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Social media metadata (generic for non-paste pages)
    meta_title = "Pasto - Help & Usage Guide"
    meta_description = "Learn how to use Pasto, a modern pastebin with live syntax highlighting and SSH access"
    meta_url = ""
    meta_image = ""

    content = render "src/views/help.ecr"
    render "src/views/layout.ecr"
  end
end
