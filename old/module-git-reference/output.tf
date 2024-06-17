#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

output "git_reference" {
  description = "value of the git reference"
  value       = data.external.git_reference.result.git_reference
}
