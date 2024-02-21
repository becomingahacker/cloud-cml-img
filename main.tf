#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  cfg_file = file("config.yml")
  cfg      = yamldecode(local.cfg_file)
}

provider "aws" {
  default_tags {
    tags = {
      Project = "cloud-cml"
    }
  }
}

module "git_reference" {
  source = "./module-git-reference"
}

module "cml_build" {
  source                        = "./module-cml2-build"
  region                        = local.cfg.aws.region
  subnet_name                   = local.cfg.aws.subnet
  security_group_name           = local.cfg.aws.security_group
  instance_type                 = local.cfg.aws.flavor
  iam_instance_profile          = local.cfg.aws.profile
  disk_size                     = local.cfg.aws.disk_size
  ssh_key_name                  = local.cfg.aws.ssh_key_name
  bucket_name                   = local.cfg.aws.bucket
  reference_platforms           = local.cfg.cml.reference_platforms
  cml_debian_package            = local.cfg.cml.debian_package
  git_reference                 = module.git_reference.git_reference
  terminate_instance_on_failure = !local.cfg.debug
  build_version                 = local.cfg.version
}
