require "baked_file_system"
require "baked_file_handler"

# Asset handling for Pasto application
module Pasto
  class PastoAssets
    extend BakedFileSystem
    bake_folder "baked/assets"
  end

  # Font assets for PNG preview generation
  class FontAssets
    extend BakedFileSystem
    bake_folder "baked/fonts"
  end

  # Favicon redirect for browsers that request /favicon without extension
  get "/favicon" do |env|
    env.response.status_code = 301
    env.response.headers["Location"] = "/assets/favicon.png"
    ""
  end

  # Favicon routes - redirect to actual favicon file
  get "/favicon.ico" do |env|
    env.redirect "/assets/favicon.png"
  end

  get "/favicon.png" do |env|
    env.redirect "/assets/favicon.png"
  end
end
