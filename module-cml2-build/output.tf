#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

output "cloud_cml_image_arn" {
  value       = aws_imagebuilder_image.cloud_cml_image.arn
  description = "ARN of the Cisco Modeling Labs image"
}

output "cloud_cml_image_ami_id" {
  value       = one(aws_imagebuilder_image.cloud_cml_image.output_resources[0].amis).image
  description = "AMI ID of the Cisco Modeling Labs image"
}
