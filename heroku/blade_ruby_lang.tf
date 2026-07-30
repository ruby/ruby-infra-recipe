resource "heroku_app" "blade_ruby_lang" {
  name   = "blade-ruby-lang"
  region = "us"
  stack  = "heroku-24"
  acm    = true

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "blade_ruby_lang_web" {
  app_id   = heroku_app.blade_ruby_lang.id
  type     = "web"
  quantity = 10
  size     = "performance-m"
}

resource "heroku_addon" "blade_ruby_lang_postgresql" {
  app_id = heroku_app.blade_ruby_lang.id
  plan   = "heroku-postgresql:standard-0"
}

resource "heroku_domain" "blade_ruby_lang_blade_ruby_lang_org" {
  app_id   = heroku_app.blade_ruby_lang.id
  hostname = "blade.ruby-lang.org"
}

resource "heroku_pipeline_coupling" "blade_ruby_lang" {
  app_id   = heroku_app.blade_ruby_lang.id
  pipeline = heroku_pipeline.blade_ruby_lang.id
  stage    = "production"
}
