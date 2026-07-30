#!/bin/sh
# Import the existing Heroku resources into a fresh state.
set -eu

terraform import heroku_pipeline.blade_ruby_lang c02d3ee8-cd12-43bd-9d75-e4d1d408014a
terraform import heroku_pipeline.bugs_ruby_lang b4e10d66-b4da-4955-a931-3182b9997b43
terraform import heroku_pipeline.rubyci 304ceee7-b0f7-475d-8327-140ed8efbbdc

terraform import heroku_app.blade_ruby_lang blade-ruby-lang
terraform import heroku_formation.blade_ruby_lang_web blade-ruby-lang:web
terraform import heroku_addon.blade_ruby_lang_postgresql blade-ruby-lang:postgresql-clean-66367
terraform import heroku_domain.blade_ruby_lang_blade_ruby_lang_org blade-ruby-lang:blade.ruby-lang.org
terraform import heroku_pipeline_coupling.blade_ruby_lang 0544cc61-ba97-4ac7-96fc-b81ab1211a60

terraform import heroku_app.bugs_ruby_lang bugs-ruby-lang
terraform import heroku_formation.bugs_ruby_lang_web bugs-ruby-lang:web
terraform import heroku_formation.bugs_ruby_lang_worker bugs-ruby-lang:worker
terraform import heroku_addon.bugs_ruby_lang_postgresql bugs-ruby-lang:postgresql-graceful-51737
terraform import heroku_addon.bugs_ruby_lang_redis bugs-ruby-lang:redis-slippery-68921
terraform import heroku_addon.bugs_ruby_lang_scheduler bugs-ruby-lang:maturing-simply-1136
terraform import heroku_addon.bugs_ruby_lang_sendgrid bugs-ruby-lang:reading-purely-3290
terraform import heroku_domain.bugs_ruby_lang_bugs_ruby_lang_org bugs-ruby-lang:bugs.ruby-lang.org
terraform import heroku_domain.bugs_ruby_lang_redmine_ruby_lang_org bugs-ruby-lang:redmine.ruby-lang.org
terraform import heroku_pipeline_coupling.bugs_ruby_lang dc7677c2-bbeb-4e87-a05e-41bd43d4fa14

terraform import heroku_app.cache_ruby_lang cache-ruby-lang
terraform import heroku_formation.cache_ruby_lang_web cache-ruby-lang:web

terraform import heroku_app.dev_meeting dev-meeting
terraform import heroku_formation.dev_meeting_web dev-meeting:web
terraform import heroku_addon.dev_meeting_scheduler dev-meeting:scheduler-tetrahedral-35215

terraform import heroku_app.h1_channel_creator h1-channel-creator
terraform import heroku_formation.h1_channel_creator_web h1-channel-creator:web

terraform import heroku_app.play_ruby play-ruby
terraform import heroku_formation.play_ruby_web play-ruby:web

terraform import heroku_app.ruboty_ruby_jp ruboty-ruby-jp
terraform import heroku_formation.ruboty_ruby_jp_bot ruboty-ruby-jp:bot
terraform import heroku_addon.ruboty_ruby_jp_redis ruboty-ruby-jp:redis-elliptical-49441
terraform import heroku_addon.ruboty_ruby_jp_papertrail ruboty-ruby-jp:papertrail-fitted-50587

terraform import heroku_app.ruby_lang_ruboty ruby-lang-ruboty
terraform import heroku_formation.ruby_lang_ruboty_bot ruby-lang-ruboty:bot
terraform import heroku_addon.ruby_lang_ruboty_redis ruby-lang-ruboty:redis-convex-54141
terraform import heroku_addon.ruby_lang_ruboty_papertrail ruby-lang-ruboty:papertrail-tapered-99523

terraform import heroku_app.rubyci rubyci
terraform import heroku_formation.rubyci_web rubyci:web
terraform import heroku_addon.rubyci_postgresql rubyci:postgresql-closed-35367
terraform import heroku_addon.rubyci_scheduler rubyci:scheduler-corrugated-95440
terraform import heroku_domain.rubyci_rubyci_org rubyci:rubyci.org
terraform import heroku_domain.rubyci_www_rubyci_org rubyci:www.rubyci.org
terraform import heroku_pipeline_coupling.rubyci 4f3759be-9bb6-40e4-8a96-f48791ff16b4

terraform import heroku_app.simpler_alerts_bot simpler-alerts-bot
terraform import heroku_formation.simpler_alerts_bot_web simpler-alerts-bot:web
terraform import heroku_addon.simpler_alerts_bot_redis simpler-alerts-bot:redis-angular-34926

terraform import heroku_app.staging_blade_ruby_lang staging-blade-ruby-lang
terraform import heroku_formation.staging_blade_ruby_lang_web staging-blade-ruby-lang:web
terraform import heroku_addon.staging_blade_ruby_lang_postgresql staging-blade-ruby-lang:postgresql-contoured-39452
terraform import heroku_pipeline_coupling.staging_blade_ruby_lang aa9d42be-e476-4310-bdde-35928e6ff0ae

terraform import heroku_app.staging_bugs_ruby_lang staging-bugs-ruby-lang
terraform import heroku_formation.staging_bugs_ruby_lang_web staging-bugs-ruby-lang:web
terraform import heroku_formation.staging_bugs_ruby_lang_worker staging-bugs-ruby-lang:worker
terraform import heroku_addon.staging_bugs_ruby_lang_postgresql staging-bugs-ruby-lang:postgresql-trapezoidal-91420
terraform import heroku_addon.staging_bugs_ruby_lang_redis staging-bugs-ruby-lang:redis-deep-01036
terraform import heroku_addon.staging_bugs_ruby_lang_sendgrid staging-bugs-ruby-lang:imagining-deftly-5591
terraform import heroku_pipeline_coupling.staging_bugs_ruby_lang 7535fac7-f955-494d-9863-afa8940637dc

terraform import heroku_app.staging_rubyci staging-rubyci
terraform import heroku_formation.staging_rubyci_web staging-rubyci:web
terraform import heroku_addon.staging_rubyci_postgresql staging-rubyci:postgresql-silhouetted-78536
terraform import heroku_pipeline_coupling.staging_rubyci 8b9d33db-44c4-4bce-b0f4-32555c0678ce
