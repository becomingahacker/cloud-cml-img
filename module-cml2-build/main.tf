#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  script_cml_sh = templatefile("${path.module}/templates/cml.sh.tftmpl", {
    debug_build  = var.debug_build
    copy_refplat = var.copy_refplat
  })
  script_config_sh = templatefile("${path.module}/templates/config.sh.tftmpl", {
    region         = var.region
    bucket         = var.bucket_name
    debian_package = var.cml_debian_package
  })
  script_configure_aws_region_sh = templatefile("${path.module}/templates/configure_aws_region.sh.tftmpl", {})
  script_del_sh                  = templatefile("${path.module}/templates/del.sh.tftmpl", {})
  reference_platforms_json       = jsonencode(var.reference_platforms)
}

data "aws_key_pair" "cloud_cml_key_pair" {
  key_name = var.ssh_key_name
}

data "aws_iam_instance_profile" "cloud_cml_instance_profile" {
  name = var.iam_instance_profile
}

data "aws_security_group" "cloud_cml_security_group" {
  name = var.security_group_name
}

data "aws_subnet" "cloud_cml_subnet" {
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "cloud_cml_infra_config" {
  description                   = "Infrastructure for building Cisco Modeling Labs in the Cloud"
  instance_profile_name         = data.aws_iam_instance_profile.cloud_cml_instance_profile.name
  instance_types                = [var.instance_type]
  key_pair                      = data.aws_key_pair.cloud_cml_key_pair.key_name
  name                          = "cloud_cml_infra_config"
  security_group_ids            = [data.aws_security_group.cloud_cml_security_group.id]
  subnet_id                     = data.aws_subnet.cloud_cml_subnet.id
  terminate_instance_on_failure = var.terminate_instance_on_failure

  #sns_topic_arn                 = aws_sns_topic.example.arn
  #logging {
  #  s3_logs {
  #    s3_bucket_name = aws_s3_bucket.example.bucket
  #    s3_key_prefix  = "logs"
  #  }
  #}
}

data "aws_ami" "ubuntu_focal_server_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_imagebuilder_component" "component_cml_install" {
  name        = "component_cml_install"
  description = "Install Cisco Modeling Labs"
  platform    = "Linux"
  version     = var.build_version
  data = yamlencode({
    schemaVersion = 1.0
    phases = [
      {
        name = "build"
        steps = [
          {
            action    = "ExecuteBash"
            name      = "Install_Dependencies"
            onFailure = "Abort"
            inputs = {
              commands = [
                "apt update",
                "apt upgrade -y",
                "apt install -y qemu-utils jq awscli git curl",
              ]
            }
          },
          {
            action    = "CreateFolder"
            name      = "Create_Provision_Folder"
            onFailure = "Abort"
            inputs = [
              {
                path        = "/provision"
                owner       = "root"
                group       = "root"
                permissions = "0755"
              },
            ]
          },
          {
            action    = "CreateFile"
            name      = "Create_CML_Install_Scripts_And_Configs"
            onFailure = "Abort"
            inputs = [
              {
                path        = "/provision/cml.sh"
                content     = local.script_cml_sh
                permissions = "0755"
              },
              {
                path        = "/provision/del.sh"
                content     = local.script_del_sh
                permissions = "0755"
              },
              {
                path        = "/provision/config.sh"
                content     = local.script_config_sh
                permissions = "0644"
              },
              {
                path        = "/provision/configure_aws_region.sh"
                content     = local.script_configure_aws_region_sh
                permissions = "0755"
              },
              {
                path        = "/provision/reference_platforms.json"
                content     = local.reference_platforms_json
                permissions = "0644"
              },
            ]
          },
          {
            action    = "ExecuteBash"
            name      = "Install_CML"
            onFailure = "Abort"
            inputs = {
              commands = [
                "/provision/cml.sh",
                "systemctl stop nginx",
                # Increase the client_max_body_size to 64G to support larger QCOW2 image uploads
                "sed -ie 's/client_max_body_size 16G;/client_max_body_size 64G;/' /etc/nginx/conf.d/controller.conf",
              ]
            }
          },
        ]
      },
    ]
  })
}

resource "aws_imagebuilder_image_recipe" "cloud_cml_image_recipe" {
  name         = "cloud_cml_image_recipe"
  parent_image = data.aws_ami.ubuntu_focal_server_ami.id
  version      = var.build_version

  block_device_mapping {
    device_name = "/dev/sda1"

    ebs {
      delete_on_termination = true
      volume_size           = var.disk_size
      volume_type           = "io2"
      iops                  = 2000
    }
  }

  component {
    component_arn = aws_imagebuilder_component.component_cml_install.arn
  }

  working_directory = "/root"

  # Remove Amazon "Systems Manager" agent after build
  systems_manager_agent {
    uninstall_after_build = var.uninstall_systems_manager_agent
  }
}

resource "aws_imagebuilder_distribution_configuration" "cloud_cml_image_distribution" {
  name = "cloud_cml_image_distribution"

  description = "Distribution for Building Cisco Modeling Labs in the Cloud"

  distribution {
    region = var.region
    ami_distribution_configuration {
      name        = "cloud-cml-{{ imagebuilder:buildDate }}"
      description = "Cloud Cisco Modeling Labs AMI"
      ami_tags = {
        Name          = "cloud-cml-{{ imagebuilder:buildDate }}"
        Git_Reference = var.git_reference
        Version       = var.build_version
      }
    }
  }
}

resource "aws_imagebuilder_image" "cloud_cml_image" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.cloud_cml_image_recipe.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.cloud_cml_image_distribution.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.cloud_cml_infra_config.arn

  # Don't run the image after it's built
  image_tests_configuration {
    image_tests_enabled = false
  }

  enhanced_image_metadata_enabled = false

  # Increase if the build takes longer than expected
  timeouts {
    create = "60m"
  }
}
