resource "heroku_app" "ruby_lang_ruboty" {
  name   = "ruby-lang-ruboty"
  region = "us"
  stack  = "heroku-20"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "ruby_lang_ruboty_bot" {
  app_id   = heroku_app.ruby_lang_ruboty.id
  type     = "bot"
  quantity = 1
  size     = "standard-1x"
}

resource "heroku_addon" "ruby_lang_ruboty_redis" {
  app_id = heroku_app.ruby_lang_ruboty.id
  plan   = "heroku-redis:mini"
}

resource "heroku_addon" "ruby_lang_ruboty_papertrail" {
  app_id = heroku_app.ruby_lang_ruboty.id
  plan   = "papertrail:choklad"
}
