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

variable "zone" {
    type        = string
    default     = ""
    description = "Zone, e.g. us-east1-b."
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
}

source "googlecompute" "cloud-cml-amd64" {
  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [ var.source_image_project_id ]
  image_family            = "cloud-cml-amd64"
  image_name              = "cloud-cml-{{timestamp}}-amd64"

  zone                    = var.zone
  machine_type            = "n2-highcpu-8"

  disk_size               = 32
  disk_type               = "pd-ssd"
  image_storage_locations = [
    "us-east1",
  ]

  ssh_username            = "root"
  service_account_email   = var.service_account_email

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

build {
  sources = ["sources.googlecompute.cloud-cml-amd64"]

  # Make sure the /provision directory exists.
  provisioner "shell" {
    only           = [
      "googlecompute.cloud-cml-amd64",
    ]

    inline = [
      "mkdir -vp /provision",
    ]
  }

  # Copy everything from the workspace to the /provision directory.
  provisioner "file" {
    only        = [
      "googlecompute.cloud-cml-amd64",
    ]

    source      = "/workspace/"
    destination = "/provision"
  }

  provisioner "shell" {
    only           = [
      "googlecompute.cloud-cml-amd64",
    ]

    script = var.provision_script

    env = { 
      APT_OPTS        = "-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew -o DPkg::Progress-Fancy=0 -o APT::Color=0"
      DEBIAN_FRONTEND = "noninteractive"
      CFG_GCP_BUCKET  = var.gcs_artifact_bucket
      CFG_CML_PACKAGE = var.cml_package
    }
  }

  post-processor "manifest" {
    only           = [
      "googlecompute.cloud-cml-amd64",
    ]
    output = "manifest.json"
    strip_path = true
    custom_data = {
      timestamp = "{{timestamp}}"
    }
  }
}