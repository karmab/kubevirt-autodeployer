#!/usr/bin/env bash

set -x
source environment.gcp
$PACKER build -debug -machine-readable --force $PACKER_BUILD_TEMPLATE | tee build.log
