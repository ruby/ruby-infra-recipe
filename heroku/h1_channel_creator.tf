resource "heroku_app" "h1_channel_creator" {
  name   = "h1-channel-creator"
  region = "us"
  stack  = "heroku-24"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "h1_channel_creator_web" {
  app_id   = heroku_app.h1_channel_creator.id
  type     = "web"
  quantity = 1
  size     = "standard-1x"
}
