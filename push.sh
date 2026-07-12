#!/bin/sh
set -eu

REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-imkebe}"
IMAGE_NAME="${IMAGE_NAME:-homeassistant-armv7-lean}"
PUBLISH_IMAGE_NAME="${PUBLISH_IMAGE_NAME:-homeassistant-armv7}"
HA_VERSION="${HA_VERSION:-2026.7.1}"
IMAGE_TAG="${IMAGE_TAG:-$HA_VERSION}"

SRC="${IMAGE_NAME}:${IMAGE_TAG}"
DST="${REGISTRY}/${NAMESPACE}/${PUBLISH_IMAGE_NAME}:${IMAGE_TAG}"

echo "Tagging ${SRC} -> ${DST}"
docker tag "${SRC}" "${DST}"

echo "Pushing ${DST}"
docker push "${DST}"

echo "Done."
