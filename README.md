# Kubevirt Auto deployer

this repo contains code to create a gcp image that, upon booting will deploy latest:

- kubernetes
- flannel
- kubevirt
- cdi

Alternatively, the following metadata can be provided in GCP to override versions:

- k8s_version
- flannel_version
- kubevirt_version
- cdi_version


## Building the image for GCP

```
source environment.gcp
sh build.sh
```

the resulting image can then be used

## Using a public image

We host a public version of the image on [Google Storage](https://console.cloud.google.com/storage/browser/kubevirt-button)

## Publishing a given image

```
PROJECT="cnvlab-209908"
BUCKET="kubevirt-button"
IMAGE="kubevirt-autodeployer"
VERSION="v0.1.0"
gcloud compute images export --destination-uri gs://$BUCKET/$VERSION.tar.gz --image $IMAGE --project $PROJECT
```
