resource "heroku_app" "staging_rubyci" {
  name   = "staging-rubyci"
  region = "us"
  stack  = "heroku-24"

  buildpacks = [
    "https://github.com/DataDog/heroku-buildpack-datadog.git",
    "heroku/nodejs",
    "heroku/ruby",
  ]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "staging_rubyci_web" {
  app_id   = heroku_app.staging_rubyci.id
  type     = "web"
  quantity = 1
  size     = "standard-2x"
}

resource "heroku_addon" "staging_rubyci_postgresql" {
  app_id = heroku_app.staging_rubyci.id
  plan   = "heroku-postgresql:standard-0"
}

resource "heroku_pipeline_coupling" "staging_rubyci" {
  app_id   = heroku_app.staging_rubyci.id
  pipeline = heroku_pipeline.rubyci.id
  stage    = "staging"
}
