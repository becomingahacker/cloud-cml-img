#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

data "external" "git_reference" {
  program = ["bash", "${path.module}/git_reference.sh"]
}
