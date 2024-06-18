#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

set -e
set -x

env

find /tmp -ls

# HACK cmm - Disable security.ubuntu.com so we don't get throttled
sed -i 's@deb http://security.ubuntu.com@# deb http://security.ubuntu.com@' /etc/apt/sources.list
# Wait for possible auto updates to complete.  This may not be needed
flock -w 120 /var/lib/apt/lists/lock -c 'echo waiting for lock'

apt-get update
apt-get upgrade -y

# Set the locale to en_US.UTF-8
locale-gen en_US
locale-gen en_US.UTF-8
dpkg-reconfigure locales
update-locale LANG=en_US.UTF-8

# Set the timezone to Eastern
timedatectl set-timezone Etc/UTC

touch /tmp/PACKER_BUILD

./cml.sh

cat > /etc/cloud/clean.d/10-cml-clean <<EOF
#!/bin/sh -x

sudo rm /etc/hosts
sudo rm /etc/hostname

sudo rm /home/root/.bash_history
sudo truncate -s 0 /home/root/.ssh/authorized_keys

# Clean up packages that can be removed
apt-get autoremove --purge -y
apt-get clean

EOF
chmod u+x /etc/cloud/clean.d/10-cml-clean

cloud-init clean -c all -l --machine-id
