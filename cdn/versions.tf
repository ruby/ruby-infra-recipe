terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "ruby-lang-terraform-state"
    key          = "cdn/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }

  required_providers {
    fastly = {
      source  = "fastly/fastly"
      version = "~> 9.4"
    }
  }
}
