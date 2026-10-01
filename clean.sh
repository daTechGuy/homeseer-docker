#!/bin/bash -e

############################################
# HOMESEER (V4) LINUX - DOCKER CLEAN SCRIPT
############################################

IMAGE="${IMAGE:-ghcr.io/datechguy/homeseer}"

echo
echo "**********************************************************************"
echo "* CLEANING HOMESEER DOCKER IMAGES                                    *"
echo "**********************************************************************"
echo

# remove the builder instance
docker buildx rm homeseer-builder || true

# remove any HomeSeer images from the local Docker image store
docker images --format '{{.Repository}}:{{.Tag}}' "$IMAGE" | xargs -r docker rmi
