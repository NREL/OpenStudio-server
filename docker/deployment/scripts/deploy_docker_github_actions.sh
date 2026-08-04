#!/usr/bin/env bash
# Tags the locally-built images with an arch suffix and pushes them.
# The canonical (multi-arch) tags are created later by
# merge_manifests_github_actions.sh.
#
# Required env: DOCKER_USER, DOCKER_PASS
# Optional env: DEPLOY_ARCH (amd64|arm64, default amd64)
set -euo pipefail

source "$(dirname "$0")/get_image_tag.sh"
DEPLOY_ARCH=${DEPLOY_ARCH:-amd64}

if [ "${IMAGETAG}" == "skip" ]; then
    echo "Not on a deployable branch [master/develop/179/...] or this is a pull request"
    exit 0
fi

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

# Push arch-suffixed images. The canonical tags are assembled by the manifest
# job so that parallel amd64/arm64 pushes never clobber each other.
for IMAGE in nrel/openstudio-server nrel/openstudio-rserve; do
    echo "Tagging image as ${IMAGE}:${IMAGETAG}-${DEPLOY_ARCH}"
    docker tag "${IMAGE}" "${IMAGE}:${IMAGETAG}-${DEPLOY_ARCH}"
    docker push "${IMAGE}:${IMAGETAG}-${DEPLOY_ARCH}"
done

if [ "${GITHUB_REF}" == "refs/heads/master" ]; then
    # Deploy master as the latest.
    for IMAGE in nrel/openstudio-server nrel/openstudio-rserve; do
        docker tag "${IMAGE}" "${IMAGE}:latest-${DEPLOY_ARCH}"
        docker push "${IMAGE}:latest-${DEPLOY_ARCH}"
    done
fi

echo "Done pushing ${DEPLOY_ARCH} artifacts for ${IMAGETAG}"
