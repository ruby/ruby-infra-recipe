resource "heroku_app" "bugs_ruby_lang" {
  name   = "bugs-ruby-lang"
  region = "us"
  stack  = "heroku-24"
  acm    = true

  buildpacks = [
    # Heroku stores the resolved registry tarball, not the shorthand name.
    "https://buildpack-registry.s3.amazonaws.com/buildpacks/heroku-community/apt.tgz",
    "https://github.com/DataDog/heroku-buildpack-datadog.git",
    "heroku/nodejs",
    "heroku/ruby",
    "https://github.com/ruby/heroku-buildpack-bugs-ruby-lang",
  ]

  organization {
    name = "ruby-core"
  }
}

resource "heroku_formation" "bugs_ruby_lang_web" {
  app_id   = heroku_app.bugs_ruby_lang.id
  type     = "web"
  quantity = 2
  size     = "performance-m"
}

resource "heroku_formation" "bugs_ruby_lang_worker" {
  app_id   = heroku_app.bugs_ruby_lang.id
  type     = "worker"
  quantity = 1
  size     = "performance-m"
}

resource "heroku_addon" "bugs_ruby_lang_postgresql" {
  app_id = heroku_app.bugs_ruby_lang.id
  plan   = "heroku-postgresql:premium-0"
}

resource "heroku_addon" "bugs_ruby_lang_redis" {
  app_id = heroku_app.bugs_ruby_lang.id
  plan   = "heroku-redis:premium-0"
}

resource "heroku_addon" "bugs_ruby_lang_scheduler" {
  app_id = heroku_app.bugs_ruby_lang.id
  plan   = "scheduler:standard"
}

resource "heroku_addon" "bugs_ruby_lang_sendgrid" {
  app_id = heroku_app.bugs_ruby_lang.id
  plan   = "sendgrid:essentials50k"
}

resource "heroku_domain" "bugs_ruby_lang_bugs_ruby_lang_org" {
  app_id   = heroku_app.bugs_ruby_lang.id
  hostname = "bugs.ruby-lang.org"
}

resource "heroku_domain" "bugs_ruby_lang_redmine_ruby_lang_org" {
  app_id   = heroku_app.bugs_ruby_lang.id
  hostname = "redmine.ruby-lang.org"
}

resource "heroku_pipeline_coupling" "bugs_ruby_lang" {
  app_id   = heroku_app.bugs_ruby_lang.id
  pipeline = heroku_pipeline.bugs_ruby_lang.id
  stage    = "production"
}
