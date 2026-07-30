#!/bin/sh
# Import the existing Heroku resources into the state.
# Safe to re-run: resources already present in the state are skipped.
set -eu

existing=$(terraform state list 2>/dev/null || true)

import() {
  if printf "%s\n" "$existing" | grep -qxF "$1"; then
    echo "skip $1"
    return 0
  fi
  terraform import "$1" "$2"
}

import heroku_pipeline.blade_ruby_lang c02d3ee8-cd12-43bd-9d75-e4d1d408014a
import heroku_pipeline.bugs_ruby_lang b4e10d66-b4da-4955-a931-3182b9997b43
import heroku_pipeline.rubyci 304ceee7-b0f7-475d-8327-140ed8efbbdc
import heroku_app.blade_ruby_lang blade-ruby-lang
import heroku_formation.blade_ruby_lang_web blade-ruby-lang:web
import heroku_addon.blade_ruby_lang_postgresql d130fe08-2d1b-4d82-9349-a2bbd736cff3
import heroku_domain.blade_ruby_lang_blade_ruby_lang_org blade-ruby-lang:blade.ruby-lang.org
import heroku_pipeline_coupling.blade_ruby_lang 0544cc61-ba97-4ac7-96fc-b81ab1211a60
import heroku_app.bugs_ruby_lang bugs-ruby-lang
import heroku_formation.bugs_ruby_lang_web bugs-ruby-lang:web
import heroku_formation.bugs_ruby_lang_worker bugs-ruby-lang:worker
import heroku_addon.bugs_ruby_lang_postgresql aa7cae35-b29d-4505-a64e-57cedb554ee0
import heroku_addon.bugs_ruby_lang_redis a25fc2ad-09f8-4e11-b453-c93efb4f13d6
import heroku_addon.bugs_ruby_lang_scheduler a54d3f5d-a362-4e96-b889-cab53611c6c6
import heroku_addon.bugs_ruby_lang_sendgrid e38bbe99-332c-42e8-93d5-042b190cb910
import heroku_domain.bugs_ruby_lang_bugs_ruby_lang_org bugs-ruby-lang:bugs.ruby-lang.org
import heroku_domain.bugs_ruby_lang_redmine_ruby_lang_org bugs-ruby-lang:redmine.ruby-lang.org
import heroku_pipeline_coupling.bugs_ruby_lang dc7677c2-bbeb-4e87-a05e-41bd43d4fa14
import heroku_app.cache_ruby_lang cache-ruby-lang
import heroku_formation.cache_ruby_lang_web cache-ruby-lang:web
import heroku_app.dev_meeting dev-meeting
import heroku_formation.dev_meeting_web dev-meeting:web
import heroku_addon.dev_meeting_scheduler ca279298-dfe4-4ef1-9348-e4723cd992e5
import heroku_app.h1_channel_creator h1-channel-creator
import heroku_formation.h1_channel_creator_web h1-channel-creator:web
import heroku_app.play_ruby play-ruby
import heroku_formation.play_ruby_web play-ruby:web
import heroku_app.ruboty_ruby_jp ruboty-ruby-jp
import heroku_formation.ruboty_ruby_jp_bot ruboty-ruby-jp:bot
import heroku_addon.ruboty_ruby_jp_redis 88d1cadf-bd04-49f9-954d-9ae236fe4530
import heroku_addon.ruboty_ruby_jp_papertrail 2905df53-88a9-4fd6-9b2a-8bcb4fc48d19
import heroku_app.ruby_lang_ruboty ruby-lang-ruboty
import heroku_formation.ruby_lang_ruboty_bot ruby-lang-ruboty:bot
import heroku_addon.ruby_lang_ruboty_redis 6d859eff-789d-4863-b8fe-f8b49c24897c
import heroku_addon.ruby_lang_ruboty_papertrail aee6dc01-625d-49f2-a5de-1df47f8a3071
import heroku_app.rubyci rubyci
import heroku_formation.rubyci_web rubyci:web
import heroku_addon.rubyci_postgresql 97f6fc22-c623-4814-a4c1-398f00e97be8
import heroku_addon.rubyci_scheduler 68bd3cd7-4c8b-43bb-9af8-a299927e152a
import heroku_domain.rubyci_rubyci_org rubyci:rubyci.org
import heroku_domain.rubyci_www_rubyci_org rubyci:www.rubyci.org
import heroku_pipeline_coupling.rubyci 4f3759be-9bb6-40e4-8a96-f48791ff16b4
import heroku_app.simpler_alerts_bot simpler-alerts-bot
import heroku_formation.simpler_alerts_bot_web simpler-alerts-bot:web
import heroku_addon.simpler_alerts_bot_redis ddc58da5-bb3e-4b8a-9736-d732d5410b4b
import heroku_app.staging_blade_ruby_lang staging-blade-ruby-lang
import heroku_formation.staging_blade_ruby_lang_web staging-blade-ruby-lang:web
import heroku_addon.staging_blade_ruby_lang_postgresql 02ec709c-db8b-478a-a316-ac93091f70ec
import heroku_pipeline_coupling.staging_blade_ruby_lang aa9d42be-e476-4310-bdde-35928e6ff0ae
import heroku_app.staging_bugs_ruby_lang staging-bugs-ruby-lang
import heroku_formation.staging_bugs_ruby_lang_web staging-bugs-ruby-lang:web
import heroku_formation.staging_bugs_ruby_lang_worker staging-bugs-ruby-lang:worker
import heroku_addon.staging_bugs_ruby_lang_postgresql c19e8053-568e-4297-9a1b-37e302a7c834
import heroku_addon.staging_bugs_ruby_lang_redis 5c262a4a-d556-4395-ac6f-688cf8a193e1
import heroku_addon.staging_bugs_ruby_lang_sendgrid 870a5ae9-374f-4056-9c90-8b094452199a
import heroku_pipeline_coupling.staging_bugs_ruby_lang 7535fac7-f955-494d-9863-afa8940637dc
import heroku_app.staging_rubyci staging-rubyci
import heroku_formation.staging_rubyci_web staging-rubyci:web
import heroku_addon.staging_rubyci_postgresql ae4ab19a-7e18-4142-beb8-6ca8a2549766
import heroku_pipeline_coupling.staging_rubyci 8b9d33db-44c4-4bce-b0f4-32555c0678ce
