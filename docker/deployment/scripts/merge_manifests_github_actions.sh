#!/usr/bin/env bash
# Merges the arch-suffixed images pushed by deploy_docker_github_actions.sh
# into canonical multi-arch manifests (e.g.
# nrel/openstudio-server:3.10.0-179-amd64 + -arm64 -> :3.10.0-179).
# Requires docker buildx (bundled with Docker CLI 19.03+).
#
# Required env: DOCKER_USER, DOCKER_PASS
set -euo pipefail

source "$(dirname "$0")/get_image_tag.sh"

if [ "${IMAGETAG}" == "skip" ]; then
    echo "Nothing to merge — not on a deployable branch"
    exit 0
fi

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

merge_image() {
    local image=$1 canonical=$2
    echo "Creating multi-arch manifest ${image}:${canonical}"
    docker buildx imagetools create \
        -t "${image}:${canonical}" \
        "${image}:${canonical}-amd64" \
        "${image}:${canonical}-arm64"
}

for IMAGE in nrel/openstudio-server nrel/openstudio-rserve; do
    merge_image "${IMAGE}" "${IMAGETAG}"
    if [ "${GITHUB_REF}" == "refs/heads/master" ]; then
        merge_image "${IMAGE}" "latest"
    fi
done

echo "Done merging multi-arch manifests for ${IMAGETAG}"
