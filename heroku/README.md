# heroku

Terraform configuration for the Heroku apps of the `ruby-core` team. Each app lives in its own `.tf` file holding its `heroku_app`, formations, add-ons and custom domains. Pipelines are in `pipelines.tf`.

Config vars are deliberately not managed here. `set_app_all_config_vars_in_state = false` is set in `versions.tf` so that secrets and add-on credentials never reach the state file. Keep using `heroku config:set` for them.

One-off process types scaled to zero (`console`, `rake`, `release`) are omitted, since only types with running dynos carry meaningful state.

## Usage

Credentials come from `~/.config/heroku/token.sh`, which must export `HEROKU_API_KEY`. Create the token with `heroku authorizations:create --description "terraform ruby-infra-recipe" --scope write-protected`, not `heroku auth:token`, which is short-lived.

`write-protected` is the narrowest scope that works. Plain `read,write` excludes config vars, and reading a `heroku_app` fails without them, because the provider always fetches `/config-vars` even though `set_app_all_config_vars_in_state = false` keeps the values out of the state file.

The state backend also needs AWS credentials that can read and write `s3://ruby-lang-terraform-state`, supplied through any standard AWS mechanism. `AWS_PROFILE=ruby-lang` works here.

```
source ~/.config/heroku/token.sh
terraform init
terraform plan
terraform apply
```

State is stored in `s3://ruby-lang-terraform-state/heroku/terraform.tfstate` (ap-northeast-1, versioned, S3 native locking).

## Importing

`import.sh` imports every resource in this directory into an empty state. Run it once after `terraform init`, then `terraform plan` until it reports no changes.

`heroku_app_config_association` is not used, so nothing tries to reconcile config vars on the first plan.

## Notes

The `ruboty-ruby-jp` and `ruby-lang-ruboty` apps still run on `heroku-20`, and `play-ruby` and `staging-blade-ruby-lang` on `heroku-22`. Bumping `stack` here triggers the upgrade on the next release.
