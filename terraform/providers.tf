terraform {
  backend "s3" {
    bucket       = "svs-zama-test"
    key          = "states/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }
  required_version = "~> 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.region
}
