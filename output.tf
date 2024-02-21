#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

output "cloud_cml_image_arn" {
  value       = module.cml_build.cloud_cml_image_arn
  description = "ARN of the Cisco Modeling Labs image"
}

output "cloud_cml_image_ami_id" {
  value       = module.cml_build.cloud_cml_image_ami_id
  description = "AMI ID of the Cisco Modeling Labs image"
}
