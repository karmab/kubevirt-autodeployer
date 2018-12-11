#!/bin/bash

PROJECT="cnvlab-209908"
BUCKET="kubevirt-button"
IMAGE="kubevirt-button"
VERSION="v0.1.0"
gcloud compute images export --destination-uri gs://$BUCKET/$VERSION.tar.gz --image $IMAGE --project $PROJECT
