#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

terraform {
  required_version = ">= 1.1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.56.0"
    }
  }

  backend "s3" {
    bucket = "bah-cml-terraform-state"
    key    = "cloud-cml-img/terraform.tfstate"
    region = "us-east-2"
  }
}
