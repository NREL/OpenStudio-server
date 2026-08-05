#!/usr/bin/env bash
# Determines the image tag based on the branch. Sourced by
# deploy_docker_github_actions.sh and merge_manifests_github_actions.sh.
# Sets IMAGETAG (or "skip" when nothing should be deployed/merged).
set -euo pipefail

IMAGETAG="skip"

if [ "${GITHUB_REF}" == "refs/heads/develop" ]; then
    IMAGETAG="develop"
elif [ "${GITHUB_REF}" == "refs/heads/2.9.X-LTS" ]; then
    IMAGETAG="2.9.X-LTS"
elif [ "${GITHUB_REF}" == "refs/heads/master" ]; then
    # Retrieve the version number from rails
    IMAGETAG="$(ruby -e "load 'server/app/lib/openstudio_server/version.rb'; print OpenstudioServer::Version+OpenstudioServer::VERSION_EXT")"
# Uncomment and set branch name for custom builds.
# Currently setting this to setup_github_actions to test upload.
elif [ "${GITHUB_REF}" == "refs/heads/setup_github_actions" ]; then
    IMAGETAG=experimental
elif [ "${GITHUB_REF}" == "refs/heads/3.10.0" ]; then
     IMAGETAG="3.10.0-rc2"
elif [ "${GITHUB_REF}" == "refs/heads/179" ]; then
     IMAGETAG="3.10.0-179"
# issue-857 zip-corruption fix candidate for cluster testing; remove mapping once merged into 179
elif [ "${GITHUB_REF}" == "refs/heads/fix/zip-read-only-extract" ]; then
     IMAGETAG="179-flock"
fi
