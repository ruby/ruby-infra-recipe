terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "ruby-lang-terraform-state"
    key          = "heroku/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }

  required_providers {
    heroku = {
      source  = "heroku/heroku"
      version = "~> 5.4"
    }
  }
}

provider "heroku" {
  customizations {
    # Keep config vars out of the state file. They are managed with the Heroku
    # CLI, and the default `true` would snapshot every value, including add-on
    # credentials and secrets set outside Terraform.
    set_app_all_config_vars_in_state = false
  }
}
