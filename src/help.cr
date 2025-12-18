# Help page endpoint for Pasto application
module Pasto
  get "/help" do |env|
    env.response.content_type = "text/html"
    current_user = Pasto.get_current_user(env)
    config = Pasto.config

    # Variables are used in ECR templates (layout.ecr)
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, config)                                            # ameba:disable Lint/UselessAssign
    page_title = "Help & Usage Guide"                                                                           # ameba:disable Lint/UselessAssign
    is_home_page = false                                                                                        # ameba:disable Lint/UselessAssign
    meta_title = "Pasto - Help & Usage Guide"                                                                   # ameba:disable Lint/UselessAssign
    meta_description = "Learn how to use Pasto, a modern pastebin with live syntax highlighting and SSH access" # ameba:disable Lint/UselessAssign
    meta_url = ""                                                                                               # ameba:disable Lint/UselessAssign
    meta_image = ""                                                                                             # ameba:disable Lint/UselessAssign
    content = render "src/views/help.ecr"                                                                       # ameba:disable Lint/UselessAssign
    render "src/views/layout.ecr"
  end
end
