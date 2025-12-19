module Pasto
  module ThemeHelper
    # Get user theme preferences with fallbacks and migrate auto to detected theme
    def self.get_theme_preferences(current_user : User?, config : Pasto::Config)
      pico_theme = current_user.try(&.pico_theme)
      if pico_theme == "auto"
        # Migrate auto users to dark (default)
        pico_theme = "dark"
        # Update user preference if possible
        if current_user
          current_user.pico_theme = pico_theme
          current_user.save rescue nil
        end
      end
      pico_theme ||= "dark"

      {
        pico_theme:   pico_theme,
        pico_color:   current_user.try(&.pico_color) || "slate",
        syntax_theme: current_user.try(&.syntax_theme) || config.theme,
      }
    end

    # Setup all theme-related template variables
    def self.setup_vars(current_user : User?, config : Pasto::Config)
      themes = get_theme_preferences(current_user, config)

      {
        saved_pico_theme:    themes[:pico_theme],
        saved_pico_color:    themes[:pico_color],
        saved_syntax_theme:  themes[:syntax_theme],
        resolved_pico_theme: themes[:pico_theme],
        pico_theme_file:     themes[:pico_color] == "css" ? "pico.min.css" : "pico.#{themes[:pico_color]}.min.css",
        theme:               config.theme,
      }
    end
  end
end
