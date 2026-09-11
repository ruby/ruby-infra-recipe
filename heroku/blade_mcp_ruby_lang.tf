resource "heroku_app" "blade_mcp_ruby_lang" {
  name   = "blade-mcp-ruby-lang"
  region = "us"
  stack  = "heroku-26"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_addon" "blade_mcp_ruby_lang_postgresql" {
  app_id = heroku_app.blade_mcp_ruby_lang.id
  plan   = "heroku-postgresql:standard-0"
}

resource "heroku_addon" "blade_mcp_ruby_lang_scheduler" {
  app_id = heroku_app.blade_mcp_ruby_lang.id
  plan   = "scheduler:standard"
}

# The standard plan serves every model, picked per request, so one add-on
# backs both names the app reads.
resource "heroku_addon" "blade_mcp_ruby_lang_inference" {
  app_id = heroku_app.blade_mcp_ruby_lang.id
  plan   = "heroku-inference:standard"
}

resource "heroku_addon_attachment" "blade_mcp_ruby_lang_embedding" {
  app_id   = heroku_app.blade_mcp_ruby_lang.id
  addon_id = heroku_addon.blade_mcp_ruby_lang_inference.id
  name     = "EMBEDDING"
}

resource "heroku_addon_attachment" "blade_mcp_ruby_lang_rerank" {
  app_id   = heroku_app.blade_mcp_ruby_lang.id
  addon_id = heroku_addon.blade_mcp_ruby_lang_inference.id
  name     = "RERANK"
}
