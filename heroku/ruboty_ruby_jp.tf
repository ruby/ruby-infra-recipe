resource "heroku_app" "ruboty_ruby_jp" {
  name   = "ruboty-ruby-jp"
  region = "us"
  stack  = "heroku-20"
  acm    = true

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "ruboty_ruby_jp_bot" {
  app_id   = heroku_app.ruboty_ruby_jp.id
  type     = "bot"
  quantity = 1
  size     = "standard-1x"
}

resource "heroku_addon" "ruboty_ruby_jp_redis" {
  app_id = heroku_app.ruboty_ruby_jp.id
  plan   = "heroku-redis:mini"
}

resource "heroku_addon" "ruboty_ruby_jp_papertrail" {
  app_id = heroku_app.ruboty_ruby_jp.id
  plan   = "papertrail:choklad"
}
