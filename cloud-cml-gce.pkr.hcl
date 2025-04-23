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

    apt = {
      sources = {
        gcsfuse = {
          # Change if base Ubuntu image changes.  Currently using Ubuntu 24.04 LTS Noble Numbat
          source = "deb https://packages.cloud.google.com/apt gcsfuse-noble main"
          key = <<-EOF
            -----BEGIN PGP PUBLIC KEY BLOCK-----

            xsBNBGCRt7MBCADkYJHHQQoL6tKrW/LbmfR9ljz7ib2aWno4JO3VKQvLwjyUMPpq
            /SXXMOnx8jXwgWizpPxQYDRJ0SQXS9ULJ1hXRL/OgMnZAYvYDeV2jBnKsAIEdiG/
            e1qm8P4W9qpWJc+hNq7FOT13RzGWRx57SdLWSXo0KeY38r9lvjjOmT/cuOcmjwlD
            T9XYf/RSO+yJ/AsyMdAr+ZbDeQUd9HYJiPdI04lGaGM02MjDMnx+monc+y54t+Z+
            ry1WtQdzoQt9dHlIPlV1tR+xV5DHHsejCZxu9TWzzSlL5wfBBeEz7R/OIzivGJpW
            QdJzd+2QDXSRg9q2XYWP5ZVtSgjVVJjNlb6ZABEBAAHNVEFydGlmYWN0IFJlZ2lz
            dHJ5IFJlcG9zaXRvcnkgU2lnbmVyIDxhcnRpZmFjdC1yZWdpc3RyeS1yZXBvc2l0
            b3J5LXNpZ25lckBnb29nbGUuY29tPsLAjgQTAQoAOBYhBDW6oLM+nrOW9ZyoOMC6
            XObcYxWjBQJgkbezAhsDBQsJCAcCBhUKCQgLAgQWAgMBAh4BAheAAAoJEMC6XObc
            YxWj+igIAMFh6DrAYMeq9sbZ1ZG6oAMrinUheGQbEqe76nIDQNsZnhDwZ2wWqgVC
            7DgOMqlhQmOmzm7M6Nzmq2dvPwq3xC2OeI9fQyzjT72deBTzLP7PJok9PJFOMdLf
            ILSsUnmMsheQt4DUO0jYAX2KUuWOIXXJaZ319QyoRNBPYa5qz7qXS7wHLOY89IDq
            fHt6Aud8ER5zhyOyhytcYMeaGC1g1IKWmgewnhEq02FantMJGlmmFi2eA0EPD02G
            C3742QGqRxLwjWsm5/TpyuU24EYKRGCRm7QdVIo3ugFSetKrn0byOxWGBvtu4fH8
            XWvZkRT+u+yzH1s5yFYBqc2JTrrJvRU=
            =QnvN
            -----END PGP PUBLIC KEY BLOCK-----
          EOF
        }
      }
    }
  }

  cloud_init_config_packages_template = [
    "curl",
    "jq",
    "frr",
    "python3-pip",
    "python3-venv",
    "gcsfuse",
  ]

  cloud_init_config_packages_controller = concat(local.cloud_init_config_packages_template,
    [
      "radvd",
    ]
  )

  cloud_init_config_packages_compute = concat(local.cloud_init_config_packages_template,
    [
    ]
  )

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
    # Don't install cml2 fully.  The rest of the install will occur
    # at first boot.
    "touch /tmp/PACKER_BUILD",
    # Don't attempt to update packages on bootup.
    "systemctl disable --now apt-daily-upgrade.service",
  ]

  cloud_init_config_controller = merge(local.cloud_init_config_template, {
    hostname = "cml-controller-build"

    packages = local.cloud_init_config_packages_controller

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

    packages = local.cloud_init_config_packages_compute

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

variable "cml_version" {
  type        = string
  default     = ""
  description = "CML version, substituting . for - (GCP limitation), e.g. 2-7-0-4"
}

source "googlecompute" "cloud-cml-controller-amd64" {

  skip_create_image = local.skip_image_creation

  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = [var.source_image_project_id]
  image_family            = "cloud-cml-controller-amd64"
  image_name              = "cloud-cml-controller-${var.cml_version}-{{timestamp}}-amd64"

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
  image_name              = "cloud-cml-compute-${var.cml_version}-{{timestamp}}-amd64"

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

      # Disable virl2 on bootup.  We'll restart it after we install.
      systemctl disable --now virl2.target
      
      #echo "Save machine-id (default password) for future use..."
      #cp /etc/machine-id /provision/saved-machine-id
      #chmod 0600 /provision/saved-machine-id
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
      # Don't wipe out the machine-id on the controller.  It's used
      # as the default CML2 password.  We change it at install.
      "echo cloud-init clean -c all -l",
      "cloud-init clean -c all -l",
      "rm -rf /var/lib/cloud",
    ]
    only = ["googlecompute.cloud-cml-controller-amd64"]
  }

  # Clean up all cloud-init data, including the machine-id.
  provisioner "shell" {
    inline = [
      "echo cloud-init clean -c all -l --machine-id",
      "cloud-init clean -c all -l --machine-id",
      "rm -rf /var/lib/cloud",
    ]
    only = ["googlecompute.cloud-cml-compute-amd64"]
  }

  post-processor "manifest" {
    output     = "/workspace/manifest.json"
    strip_path = true
    #custom_data = {
    #  foo = "bar"
    #}
  }
}