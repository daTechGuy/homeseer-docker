#!/bin/bash -e

############################################
# HOMESEER (V4) LINUX - DOCKER BUILD SCRIPT
############################################
#
# Builds the HomeSeer image for the release and beta versions listed in 'versions.env'.
# Images are normally built and published by GitHub Actions (.github/workflows/build.yml);
# this script is for local builds.
#
# USAGE:
#   ./build.sh                 build release + beta for the local platform and load into Docker
#   ./build.sh --push          build multi-arch (amd64/arm64) images and push them to the registry
#
# ENVIRONMENT:
#   IMAGE                      image name (default: ghcr.io/datechguy/homeseer)
#
cd "$(dirname "$0")"
source ./versions.env

IMAGE="${IMAGE:-ghcr.io/datechguy/homeseer}"

if [[ "$1" == "--push" ]]; then
  # use buildx to create a multi-arch builder instance; if needed
  docker buildx create --name homeseer-builder --use 2>/dev/null || docker buildx use homeseer-builder
  OUTPUT="--platform linux/amd64,linux/arm64 --push"
else
  OUTPUT="--load"
fi

build () {
  VERSION=$1
  CHANNEL=$2   # 'latest' or 'beta'
  DOWNLOAD="https://homeseer.com/updates4/linux_${VERSION//./_}.tar.gz"

  echo
  echo "**********************************************************************"
  echo "* BUILDING HOMESEER $VERSION ($CHANNEL)"
  echo "**********************************************************************"
  echo

  docker buildx build \
    --build-arg BUILDDATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg VERSION="$VERSION"   \
    --build-arg DOWNLOAD="$DOWNLOAD" \
    --tag "$IMAGE:$VERSION"          \
    --tag "$IMAGE:$CHANNEL"          \
    $OUTPUT .
}

build "$BETA_VERSION"    beta
build "$RELEASE_VERSION" latest
