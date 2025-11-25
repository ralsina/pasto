require "tartrazine"

puts "Available Tartrazine Themes:"
puts "==========================="

all_themes = Tartrazine.themes
puts "Total themes available: #{all_themes.size}"
puts

# Group themes by popularity/category
popular_themes = [
  "github", "github-dark",
  "monokai", "monokailight",
  "nord", "nord-light",
  "dracula",
  "solarized-dark", "solarized-light", "solarized-dark256",
  "material", "material-darker", "material-lighter", "material-palenight", "material-vivid",
  "gruvbox-dark-hard", "gruvbox-dark-medium", "gruvbox-dark-pale", "gruvbox-dark-soft", "gruvbox-light",
  "catppuccin-frappe", "catppuccin-latte", "catppuccin-macchiato", "catppuccin-mocha",
  "tokyonight-day", "tokyonight-moon", "tokyonight-night", "tokyonight-storm",
  "rose-pine", "rose-pine-dawn", "rose-pine-moon",
  "default-dark", "default-light",
  "vscode", "atom-dark", "pygments",
]

puts "Popular themes:"
puts "--------------"
popular_themes.each do |theme|
  if all_themes.includes?(theme)
    puts "✓ #{theme}"
  else
    puts "✗ #{theme} (not found)"
  end
end

puts
puts "All available themes (sorted):"
puts "------------------------------"
all_themes.sort.each { |theme| puts "- #{theme}" }
