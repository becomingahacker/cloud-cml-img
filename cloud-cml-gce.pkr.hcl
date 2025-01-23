#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  skip_image_creation = false

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

  cloud_init_config_template = {
    package_update  = true
    package_upgrade = true

    manage_etc_hosts = true

    locale           = "en_US.UTF-8"
    timezone         = "Etc/UTC"
  }

  cloud_init_config_packages_template = [
    "curl",
    "jq",
    "frr",
  ]

  cloud_init_config_write_files_template = [
    {
      path        = "/etc/cloud/clean.d/10-cml-clean"
      owner       = "root:root"
      permissions = "0755"
      content     = <<-EOF
        #!/bin/sh -x
        
        # Default resolver configurations
        echo "ubuntu" > /etc/hostname

        # Note that the IMDS is there. It's important for cloud-init to run properly
        # during network activation.
        cat <<EOD > /etc/hosts
        127.0.0.1 localhost

        # The following lines are desirable for IPv6 capable hosts
        ::1 ip6-localhost ip6-loopback
        fe00::0 ip6-localnet
        ff00::0 ip6-mcastprefix
        ff02::1 ip6-allnodes
        ff02::2 ip6-allrouters
        ff02::3 ip6-allhosts
        169.254.169.254 metadata.google.internal metadata
        EOD

        rm /home/root/.bash_history
        truncate -s 0 /home/root/.ssh/authorized_keys

        # Clean up packages that can be removed
        apt-get autoremove --purge -y
        apt-get clean

        # Purge the system journal
        journalctl --rotate
        journalctl --vacuum-time=1s
      EOF
    },
  ]
  cloud_init_config_runcmd_template = [
    "touch /tmp/PACKER_BUILD",
  ]

  cloud_init_config_controller = merge(local.cloud_init_config_template, {
    hostname = "cml-controller-build"

    packages = local.cloud_init_config_packages_template

    write_files = concat(local.cloud_init_config_write_files_template, [
      {
        path        = "/etc/virl2-base-config.yml"
        owner       = "root:root"
        permissions = "0640"
        content     = yamlencode(local.cml_config_controller)
      },
    ])

    runcmd = local.cloud_init_config_runcmd_template
  })

  cloud_init_config_compute = merge(local.cloud_init_config_template, {
    hostname = "cml-compute-build"

    packages = local.cloud_init_config_packages_template

    write_files = concat(local.cloud_init_config_write_files_template, [
      {
        path        = "/etc/virl2-base-config.yml"
        owner       = "root:root"
        permissions = "0640"
        content     = yamlencode(local.cml_config_compute)
      },
    ])

    runcmd = local.cloud_init_config_runcmd_template
  })
}

packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

variable "debug" {
  type        = bool
  default     = false
  description = <<-EOF
    Whether to do a debug build or not.  If set to true, the build
    will pause on failures and allow project-level SSH keys to Packer machines.
  EOF
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
  default     = "cml.sh"
  description = "Provisioning script"
}

variable "gcs_artifact_bucket" {
  type        = string
  default     = ""
  description = "GCS bucket to retrieve artifacts, e.g. gs://bah-machine-images"
}

variable "cml_package_path" {
  type        = string
  default     = ""
  description = "CML package path in bucket, e.g. cml2/cml2_2.7.0-4_amd64-20.pkg"
}


source "googlecompute" "cloud-cml-controller-amd64" {

  skip_create_image = local.skip_image_creation

  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [var.source_image_project_id]
  image_family            = "cloud-cml-controller-amd64"
  image_name              = "cloud-cml-controller-{{timestamp}}-amd64"

  zone         = var.zone
  machine_type = "n2-standard-4"
  # This will make the VM boot in UEFI mode from this image forward.
  enable_secure_boot = true

  disk_size = 32
  disk_type = "pd-ssd"
  image_storage_locations = [
    var.location,
  ]

  ssh_username            = "root"
  temporary_key_pair_type = "ed25519"

  metadata = {
    # This will prevent the project-wide SSH keys from being added to the instance.
    "block-project-ssh-keys" = ! var.debug ? "TRUE" : "FALSE"
    "user-data"              = format("#cloud-config\n%s", yamlencode(local.cloud_init_config_controller))
  }

  service_account_email = var.service_account_email

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

source "googlecompute" "cloud-cml-compute-amd64" {

  skip_create_image = local.skip_image_creation

  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [var.source_image_project_id]
  image_family            = "cloud-cml-compute-amd64"
  image_name              = "cloud-cml-compute-{{timestamp}}-amd64"

  zone         = var.zone
  machine_type = "n2-standard-4"
  # This will make the VM boot in UEFI mode from this image forward.
  enable_secure_boot = true

  disk_size = 32
  disk_type = "pd-ssd"
  image_storage_locations = [
    var.location,
  ]

  ssh_username            = "root"
  temporary_key_pair_type = "ed25519"

  metadata = {
    # This will prevent the project-wide SSH keys from being added to the instance.
    "block-project-ssh-keys" = ! var.debug ? "TRUE" : "FALSE"
    "user-data"              = format("#cloud-config\n%s", yamlencode(local.cloud_init_config_compute))
  }

  service_account_email = var.service_account_email

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}


build {
  sources = [
    "sources.googlecompute.cloud-cml-controller-amd64",
    "sources.googlecompute.cloud-cml-compute-amd64",
  ]

  provisioner "shell" {
    inline = ["mkdir -vp /provision"]
  }

  # These are files copied here, rather than in the cloud-init because we don't
  # want to do any YAML encoding/processing on them.
  provisioner "file" {
    source      = "/workspace/build-git-ref.txt"
    destination = "/provision/build-git-ref.txt"
  }

  provisioner "file" {
    source      = "/workspace/cml.sh"
    destination = "/provision/cml.sh"
  }

  provisioner "file" {
    source      = "/workspace/common.sh"
    destination = "/provision/common.sh"
  }

  provisioner "file" {
    source      = "/workspace/copyfile.sh"
    destination = "/provision/copyfile.sh"
  }

  provisioner "file" {
    source      = "/workspace/vars.sh"
    destination = "/provision/vars.sh"
  }

  provisioner "file" {
    source      = "/workspace/refplat.json"
    destination = "/provision/refplat.json"
  }

  # Let cloud-init finish before running the
  # main provisioning script.  If cloud-init fails,
  # output the log and stop the build.
  provisioner "shell" {
    inline = [<<-EOF
      echo "waiting for cloud-init setup to finish..."
      cloud-init status --wait || true

      cloud_init_state="$(cloud-init status | awk '/status:/ { print $2 }')"

      if [ "$cloud_init_state" = "done" ]; then
        echo "cloud-init setup has successfully finished"
      else
        echo "cloud-init setup is in unknown state: $cloud_init_state"
        cloud-init status --long
        cat /var/log/cloud-init-output.log
        echo "stopping build..."
        exit 1
      fi
      
      echo "Starting main provisioning script..."
      chmod u+x /provision/cml.sh
      if /provision/cml.sh; then 
        echo "Success!"
      else
        echo "Failed, displaying CML logs and stopping build..."
        if [ -d /var/log/virl2 ]; then
          find /var/log/virl2 -type f -printf '=== %p ===\n' -exec cat {} \;
        fi
      %{ if var.debug }
        echo "Debugging enabled, pausing build..."
        sleep 99999
      %{ endif }
        exit 1
      fi
      
      echo "Save machine-id (default password) for future use..."
      cp /etc/machine-id /provision/saved-machine-id
      chmod 0600 /provision/saved-machine-id
    EOF
    ]
    env = {
      CFG_GCP_BUCKET       = var.gcs_artifact_bucket
      CFG_CML_PACKAGE_PATH = var.cml_package_path
    }
  }

  # Clean up all cloud-init data.
  provisioner "shell" {
    inline = [
      "cloud-init clean -c all -l --machine-id",
      "rm -rf /var/lib/cloud",
    ]
  }

  post-processor "manifest" {
    output     = "/workspace/manifest.json"
    strip_path = true
    #custom_data = {
    #  foo = "bar"
    #}
  }
}