resource "heroku_app" "rubyci" {
  name   = "rubyci"
  region = "us"
  stack  = "heroku-24"
  acm    = true

  buildpacks = [
    "https://github.com/DataDog/heroku-buildpack-datadog.git",
    "heroku/nodejs",
    "heroku/ruby",
  ]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "rubyci_web" {
  app_id   = heroku_app.rubyci.id
  type     = "web"
  quantity = 2
  size     = "standard-2x"
}

resource "heroku_addon" "rubyci_postgresql" {
  app_id = heroku_app.rubyci.id
  plan   = "heroku-postgresql:premium-0"
}

resource "heroku_addon" "rubyci_scheduler" {
  app_id = heroku_app.rubyci.id
  plan   = "scheduler:standard"
}

resource "heroku_domain" "rubyci_rubyci_org" {
  app_id   = heroku_app.rubyci.id
  hostname = "rubyci.org"
}

resource "heroku_domain" "rubyci_www_rubyci_org" {
  app_id   = heroku_app.rubyci.id
  hostname = "www.rubyci.org"
}

resource "heroku_pipeline_coupling" "rubyci" {
  app_id   = heroku_app.rubyci.id
  pipeline = heroku_pipeline.rubyci.id
  stage    = "production"
}
