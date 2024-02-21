#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

variable "region" {
  type        = string
  description = "AWS region where the instance should be started"
}

variable "instance_type" {
  type        = string
  description = "AWS EC2 instance type to be used to build CML"
}

variable "ssh_key_name" {
  type        = string
  description = "SSH key defined in AWS EC2 to be used with CML instances"
}

variable "iam_instance_profile" {
  type        = string
  description = "AWS IAM instance profile defining the access policy used for the EC2 instance"
}

variable "disk_size" {
  type        = number
  default     = 64
  description = "Root disk size in GB"
}

variable "security_group_name" {
  type        = string
  description = "AWS security group name"
}

variable "subnet_name" {
  type        = string
  description = "AWS subnet name"
}

variable "bucket_name" {
  type        = string
  description = "AWS S3 bucket name"
}

variable "cml_debian_package" {
  type        = string
  description = "CML Debian package name"
}

variable "reference_platforms" {
  type = object({
    definitions = list(string)
    images      = list(string)
  })
  description = "List of reference platforms to be used for CML"
}

variable "terminate_instance_on_failure" {
  type        = bool
  description = "Keep the build instance running on failure"
  default     = false
}

variable "debug_build" {
  type        = bool
  description = "Debug build"
  default     = false
}

variable "git_reference" {
  type        = string
  description = "Git reference to use for the build"
  default     = "undefined"
}

variable "uninstall_systems_manager_agent" {
  type        = bool
  description = "Remove the AWS Systems Manager agent from the build instance after finishing"
  default     = true
}

variable "build_version" {
  type        = string
  description = "Version of the CML build"
  default     = "1.0.0"
}