resource "heroku_app" "dev_meeting" {
  name   = "dev-meeting"
  region = "us"
  stack  = "heroku-24"

  buildpacks = ["heroku/ruby"]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "dev_meeting_web" {
  app_id   = heroku_app.dev_meeting.id
  type     = "web"
  quantity = 1
  size     = "standard-1x"
}

resource "heroku_addon" "dev_meeting_scheduler" {
  app_id = heroku_app.dev_meeting.id
  plan   = "scheduler:standard"
}
