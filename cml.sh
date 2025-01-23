#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# :%!shfmt -ci -i 4 -
set -x
set -e

source /provision/common.sh
source /provision/copyfile.sh
source /provision/vars.sh

function setup_pre_aws() {
    export AWS_DEFAULT_REGION=${CFG_AWS_REGION}
    apt-get install -y awscli
}

function setup_pre_azure() {
    curl -LO https://aka.ms/downloadazcopy-v10-linux
    tar xvf down* --strip-components=1 -C /usr/local/bin
    chmod a+x /usr/local/bin/azcopy
}

function setup_pre_gcp() {
    return
}

function base_setup() {

    # Check if this device is a controller
    if is_controller; then
        # copy node definitions and images to the instance
        VLLI=/var/lib/libvirt/images
        NDEF=node-definitions
        IDEF=virl-base-images
        mkdir -p $VLLI/$NDEF

        # copy all node definitions as defined in the provisioned config
        if [ $(jq </provision/refplat.json '.definitions|length') -gt 0 ]; then
            elems=$(jq </provision/refplat.json -rc '.definitions|join(" ")')
            for item in $elems; do
                copyfile refplat/$NDEF/$item.yaml $VLLI/$NDEF/
            done
        fi

        # copy all image definitions as defined in the provisioned config
        if [ $(jq </provision/refplat.json '.images|length') -gt 0 ]; then
            elems=$(jq </provision/refplat.json -rc '.images|join(" ")')
            for item in $elems; do
                mkdir -p $VLLI/$IDEF/$item
                copyfile refplat/$IDEF/$item/ $VLLI/$IDEF $item --recursive
            done
        fi

        # if there's no images at this point, copy what's available in the defined
        # cloud storage container
        if [ $(find $VLLI -type f | wc -l) -eq 0 ]; then
            copyfile refplat/ $VLLI/ "" --recursive
        fi
    fi

    # Add i386 architecture for iol-tools
    # FIXME cmm - No longer required
    #dpkg --add-architecture i386

    # copy CML distribution package from cloud storage into our instance, unpack & install
    copyfile ${CFG_APP_SOFTWARE} /provision/
    tar xvf /provision/$(basename ${CFG_APP_SOFTWARE}) --wildcards -C /tmp 'cml2*_amd64.deb' 'patty*_amd64.deb' 'iol-tools*_amd64.deb'
    systemctl stop ssh
    apt-get install -y /tmp/*.deb

    # HACK cmm - Disable firewalld to break a dependency loop 
    systemctl disable firewalld
}

echo "### Provisioning via cml.sh starts"

# For troubleshooting. To allow serial console access on GCP.  This is not for production.
#echo "root:secret-password-here" | /usr/sbin/chpasswd

# Ensure non-interactive Debian package installation
APT_OPTS="-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew"
APT_OPTS+=" -o DPkg::Progress-Fancy=0 -o APT::Color=0"
DEBIAN_FRONTEND=noninteractive
export APT_OPTS DEBIAN_FRONTEND

# Run the appropriate pre-setup function
case $CFG_TARGET in
    aws)
        setup_pre_aws
        ;;
    azure)
        setup_pre_azure
        ;;
    gcp)
        setup_pre_gcp
        ;;
    *)
        echo "unknown target!"
        exit 1
        ;;
esac

base_setup
