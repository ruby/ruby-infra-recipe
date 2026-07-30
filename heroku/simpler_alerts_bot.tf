resource "heroku_app" "simpler_alerts_bot" {
  name   = "simpler-alerts-bot"
  region = "us"
  stack  = "heroku-24"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "simpler_alerts_bot_web" {
  app_id   = heroku_app.simpler_alerts_bot.id
  type     = "web"
  quantity = 1
  size     = "standard-1x"
}

resource "heroku_addon" "simpler_alerts_bot_redis" {
  app_id = heroku_app.simpler_alerts_bot.id
  plan   = "heroku-redis:premium-0"
}
