#empty dir for export
mkdir -p $GITHUB_WORKSPACE/build/NREL/export


export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin
export PATH="$GITHUB_WORKSPACE/gems/bin:/usr/local/ruby/bin:$HOME/$OS_NAME_WITH_PLUS/bin:$PATH"
export RUBYLIB="$HOME/$OS_NAME_WITH_PLUS/Ruby"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"

# Build the gems and output to tar gz file.
/usr/local/ruby/bin/ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --export="${GITHUB_WORKSPACE}/build/NREL/export"
