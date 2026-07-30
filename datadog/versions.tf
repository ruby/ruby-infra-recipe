terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "ruby-lang-terraform-state"
    key          = "datadog/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.17"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.57"
    }
  }
}

provider "datadog" {
  # The org is on AP1. The provider defaults to the US1 endpoints, which answer
  # 403 Forbidden for an AP1 key.
  api_url = "https://api.ap1.datadoghq.com/"
}

provider "aws" {
  region = "ap-northeast-1"
}
