resource "heroku_app" "staging_blade_ruby_lang" {
  name   = "staging-blade-ruby-lang"
  region = "us"
  stack  = "heroku-22"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "staging_blade_ruby_lang_web" {
  app_id   = heroku_app.staging_blade_ruby_lang.id
  type     = "web"
  quantity = 1
  size     = "basic"
}

resource "heroku_addon" "staging_blade_ruby_lang_postgresql" {
  app_id = heroku_app.staging_blade_ruby_lang.id
  plan   = "heroku-postgresql:essential-0"
}

resource "heroku_pipeline_coupling" "staging_blade_ruby_lang" {
  app_id   = heroku_app.staging_blade_ruby_lang.id
  pipeline = heroku_pipeline.blade_ruby_lang.id
  stage    = "staging"
}
