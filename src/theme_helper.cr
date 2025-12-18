module Pasto
  module ThemeHelper
    # Get user theme preferences with fallbacks
    def self.get_theme_preferences(current_user : User?, config : Pasto::Config)
      {
        pico_theme:   current_user.try(&.pico_theme) || "auto",
        pico_color:   current_user.try(&.pico_color) || "slate",
        syntax_theme: current_user.try(&.syntax_theme) || config.theme,
      }
    end

    # Resolve auto theme for server-side rendering
    def self.resolve_auto_theme(saved_pico_theme : String)
      saved_pico_theme == "auto" ? "dark" : saved_pico_theme
    end

    # Setup all theme-related template variables
    def self.setup_vars(current_user : User?, config : Pasto::Config)
      themes = get_theme_preferences(current_user, config)

      {
        saved_pico_theme:    themes[:pico_theme],
        saved_pico_color:    themes[:pico_color],
        saved_syntax_theme:  themes[:syntax_theme],
        resolved_pico_theme: resolve_auto_theme(themes[:pico_theme]),
        pico_theme_file:     themes[:pico_color] == "css" ? "pico.min.css" : "pico.#{themes[:pico_color]}.min.css",
        theme:               config.theme,
      }
    end
  end
end
