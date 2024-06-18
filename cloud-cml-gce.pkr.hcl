#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

variable "project_id" {
    type        = string
    default     = ""
    description = "Project ID, e.g. gcp-asigbahgcp-nprd-47930"
}

variable "location" {
    type        = string
    default     = ""
    description = "Region, e.g. us-east1"
}

variable "zone" {
    type        = string
    default     = ""
    description = "Zone, e.g. us-east1-b"
}

variable "service_account_email" {
    type        = string
    default     = ""
    description = "Service account to use while building."
}

variable "source_image_family" {
    type        = string
    default     = ""
    description = "Parent image family, e.g. ubuntu-2004-lts"
}

variable "source_image_project_id" {
    type        = string
    default     = ""
    description = "Parent image project, e.g. ubuntu-os-cloud"
}

variable "provision_script" {
    type        = string
    default     = "setup.sh"
    description = "Provisioning script"
}

variable "gcs_artifact_bucket" {
    type        = string
    default     = ""
    description = "GCS bucket to retrieve artifacts, e.g. gs://bah-machine-images"
}

variable "cml_package" {
    type        = string
    default     = ""
    description = "CML package, e.g. cml2_2.7.0-4_amd64-20.pkg"
}

locals {
  debug = false
  #debug = true

  cml_config_template = {
    admins = {
      controller = {
        username = ""
        password = ""
      }
      system = {
        username = ""
        password = ""
      }
    }
    cluster_interface   = ""
    compute_secret      = ""
    controller_name     = ""
    copy_iso_to_disk    = false
    interactive         = false
    is_cluster          = ""
    is_configured       = false
    primary_interface   = ""
    ssh_server          = true
    use_ipv4_dhcp       = true
    skip_primary_bridge = true
  }

  cml_config_controller = merge(local.cml_config_template, {
    is_controller = true
    is_compute    = false
  })

  cml_config_compute = merge(local.cml_config_template, {
      is_controller = false
      is_compute    = true
  })
}

source "googlecompute" "cloud-cml-controller-amd64" {

  skip_create_image       = local.debug

  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [ var.source_image_project_id ]
  image_family            = "cloud-cml-controller-amd64"
  image_name              = "cloud-cml-controller-{{timestamp}}-amd64"

  zone                    = var.zone
  machine_type            = "n2-standard-4"
  #machine_type            = "n2-highcpu-8"

  disk_size               = 32
  disk_type               = "pd-ssd"
  image_storage_locations = [
    var.location,
  ]

  ssh_username            = "root"
  temporary_key_pair_type = "ed25519"

  service_account_email   = var.service_account_email

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

source "googlecompute" "cloud-cml-compute-amd64" {

  skip_create_image       = local.debug

  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [ var.source_image_project_id ]
  image_family            = "cloud-cml-compute-amd64"
  image_name              = "cloud-cml-compute-{{timestamp}}-amd64"

  zone                    = var.zone
  machine_type            = "n2-standard-4"
  #machine_type            = "n2-highcpu-8"

  disk_size               = 32
  disk_type               = "pd-ssd"
  image_storage_locations = [
    var.location,
  ]

  ssh_username            = "root"
  temporary_key_pair_type = "ed25519"

  service_account_email   = var.service_account_email

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}


build {
  sources = [
    "sources.googlecompute.cloud-cml-controller-amd64",
    "sources.googlecompute.cloud-cml-compute-amd64",
  ]

  # Make sure the /provision directory exists.
  provisioner "shell" {
    inline = [
      "mkdir -vp /provision",
    ]
  }

  # Copy everything from the workspace to the /provision directory.
  provisioner "file" {
    source      = "/workspace/"
    destination = "/provision"
  }

  # Copy the controller configuration file to the /etc directory.
  provisioner "file" {
    only    = ["googlecompute.cloud-cml-controller-amd64"]
    content = yamlencode(local.cml_config_controller)
    destionation = "/etc/virl2-base-config.yml"
  }

  # Copy the compute configuration file to the /etc directory.
  provisioner "file" {
    only    = ["googlecompute.cloud-cml-compute-amd64"]
    content = yamlencode(local.cml_config_compute)
    destionation = "/etc/virl2-base-config.yml"
  }

  # Make sure cml.sh is executable and pause for debugging before running the
  # main provisioning script.
  provisioner "shell" {
    inline = [ <<-EOF
      chmod u+x /provision/cml.sh

      if [ "$DEBUG" = "true" ]; then
        echo "Pausing for debugging..."
        sleep 3600 || true
      fi
    EOF
    ]
    env = {
      DEBUG = local.debug
    }
  }

  provisioner "shell" {
    script = var.provision_script

    env = { 
      APT_OPTS        = "-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew -o DPkg::Progress-Fancy=0 -o APT::Color=0"
      DEBIAN_FRONTEND = "noninteractive"
      CFG_GCP_BUCKET  = var.gcs_artifact_bucket
      CFG_CML_PACKAGE = var.cml_package
    }
  }

  post-processor "manifest" {
   output = "/workspace/manifest.json"
    strip_path = true
    #custom_data = {
    #  foo = "bar"
    #}
  }
}