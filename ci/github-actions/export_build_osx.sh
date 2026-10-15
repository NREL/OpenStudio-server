#!/usr/bin/env bash
set -euo pipefail

#empty dir for export
mkdir -p $GITHUB_WORKSPACE/build/NREL/export
mkdir -p $HOME/build/NREL/export

ARCH=$(uname -m)
case "${ARCH}" in
    arm64)
        OS_ARCH="arm64"
        TARBALL_PLATFORM="darwin-arm64"
        ;;
    x86_64)
        OS_ARCH="x86_64"
        TARBALL_PLATFORM="darwin"
        ;;
    *)
        echo "Error: Unsupported macOS architecture '${ARCH}'" >&2
        exit 1
        ;;
esac

export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-${OS_ARCH}
export PATH="$GITHUB_WORKSPACE/gems/bin:/usr/local/ruby/bin:$HOME/$OS_NAME_WITH_PLUS/bin:$PATH"
export RUBYLIB="$HOME/$OS_NAME_WITH_PLUS/Ruby"
export GEM_HOME="$GITHUB_WORKSPACE/gems"
export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"
oss_filename="OpenStudio-server-$(git -C "${GITHUB_WORKSPACE}" rev-parse --short=10 HEAD)-${TARBALL_PLATFORM}.tar.gz"

# Build the gems and output to tar gz file. You need to specify a dir outside of the repo to export or 
# openstudio_meta will error. Then for sake of using relative dirs with GitHub upload-artifacts, cp the file to
# the repo working directory. 
/usr/local/ruby/bin/ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --export="${HOME}/build/NREL/export"
cp "$HOME/build/NREL/export/$oss_filename" "$GITHUB_WORKSPACE/build/NREL/export/$oss_filename"

# Verify exported tarball structure, architecture, and dylib portability for OpenStudio-PAT
verify_dir=$(mktemp -d)
trap 'rm -rf "${verify_dir}"' EXIT
tar -xzf "$GITHUB_WORKSPACE/build/NREL/export/$oss_filename" -C "${verify_dir}"

for required_dir in \
    "${verify_dir}/OpenStudio-server/bin" \
    "${verify_dir}/OpenStudio-server/server" \
    "${verify_dir}/OpenStudio-server/gems"; do
    if [ ! -d "${required_dir}" ]; then
        echo "FAIL: Missing required directory: ${required_dir}" >&2
        exit 1
    fi
done

for required_file in \
    "${verify_dir}/OpenStudio-server/bin/openstudio_meta" \
    "${verify_dir}/OpenStudio-server/Gemfile" \
    "${verify_dir}/OpenStudio-server/server/Gemfile" \
    "${verify_dir}/OpenStudio-server/server/Gemfile.lock"; do
    if [ ! -f "${required_file}" ]; then
        echo "FAIL: Missing required file: ${required_file}" >&2
        exit 1
    fi
done

dot_under=$(find "${verify_dir}" -name '._*' | wc -l | tr -d ' ')
if [ "${dot_under}" -gt 0 ]; then
    echo "FAIL: Found ${dot_under} AppleDouble ._* file(s) in archive" >&2
    exit 1
fi

nested_tarballs=$(find "${verify_dir}" -maxdepth 3 -name 'OpenStudio-server-*.tar.gz' | wc -l | tr -d ' ')
if [ "${nested_tarballs}" -gt 0 ] || [ -d "${verify_dir}/OpenStudio-server/build" ]; then
    echo "FAIL: Found nested build artifacts inside OpenStudio-server archive" >&2
    exit 1
fi

bundle_files=$(find "${verify_dir}/OpenStudio-server/gems" -name '*.bundle' -type f)
bundle_count=$(echo "${bundle_files}" | grep -c '.' || true)
if [ "${bundle_count}" -eq 0 ]; then
    echo "FAIL: No .bundle native extensions found in gems/" >&2
    exit 1
fi

while IFS= read -r bfile; do
    [ -z "${bfile}" ] && continue
    file_info=$(file "${bfile}")
    if ! echo "${file_info}" | grep -q "Mach-O.*${OS_ARCH}"; then
        echo "FAIL: Wrong architecture for ${bfile}: ${file_info}" >&2
        exit 1
    fi
    bad_load=$(otool -L "${bfile}" | tail -n +2 | awk '{print $1}' | grep -E '^(/opt/homebrew|/usr/local/Cellar|/usr/local/opt|/Users/|/private/)' || true)
    if [ -n "${bad_load}" ]; then
        echo "FAIL: Non-portable dylib reference in ${bfile}: ${bad_load}" >&2
        exit 1
    fi
done <<< "${bundle_files}"

echo "Verified ${oss_filename} (${bundle_count} native .bundle extensions for ${OS_ARCH})"