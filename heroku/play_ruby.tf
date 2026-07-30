resource "heroku_app" "play_ruby" {
  name   = "play-ruby"
  region = "us"
  stack  = "heroku-22"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "play_ruby_web" {
  app_id   = heroku_app.play_ruby.id
  type     = "web"
  quantity = 1
  size     = "basic"
}
