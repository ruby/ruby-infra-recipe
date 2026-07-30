resource "heroku_app" "cache_ruby_lang" {
  name   = "cache-ruby-lang"
  region = "us"
  stack  = "heroku-24"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "cache_ruby_lang_web" {
  app_id   = heroku_app.cache_ruby_lang.id
  type     = "web"
  quantity = 2
  size     = "standard-2x"
}
