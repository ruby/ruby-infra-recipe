resource "heroku_app" "staging_bugs_ruby_lang" {
  name   = "staging-bugs-ruby-lang"
  region = "us"
  stack  = "heroku-24"

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

resource "heroku_formation" "staging_bugs_ruby_lang_web" {
  app_id   = heroku_app.staging_bugs_ruby_lang.id
  type     = "web"
  quantity = 2
  size     = "standard-2x"
}

resource "heroku_formation" "staging_bugs_ruby_lang_worker" {
  app_id   = heroku_app.staging_bugs_ruby_lang.id
  type     = "worker"
  quantity = 1
  size     = "standard-1x"
}

resource "heroku_addon" "staging_bugs_ruby_lang_postgresql" {
  app_id = heroku_app.staging_bugs_ruby_lang.id
  plan   = "heroku-postgresql:standard-0"
}

resource "heroku_addon" "staging_bugs_ruby_lang_redis" {
  app_id = heroku_app.staging_bugs_ruby_lang.id
  plan   = "heroku-redis:mini"
}

resource "heroku_addon" "staging_bugs_ruby_lang_sendgrid" {
  app_id = heroku_app.staging_bugs_ruby_lang.id
  plan   = "sendgrid:essentials50k"
}

resource "heroku_pipeline_coupling" "staging_bugs_ruby_lang" {
  app_id   = heroku_app.staging_bugs_ruby_lang.id
  pipeline = heroku_pipeline.bugs_ruby_lang.id
  stage    = "staging"
}
