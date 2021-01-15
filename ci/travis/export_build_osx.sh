#empty dir for export
mkdir -p $GITHUB_WORKSPACE/build/NREL/export


export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin
export PATH="$GITHUB_WORKSPACE/gems/bin:/usr/local/ruby/bin:$HOME/$OS_NAME_WITH_PLUS/bin:$PATH"
export RUBYLIB="$HOME/$OS_NAME_WITH_PLUS/Ruby"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
/usr/local/ruby/bin/ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --export="${GITHUB_WORKSPACE}/build/NREL/export"
#oss_filename="OpenStudio-server-$(git -C "${GITHUB_WORKSPACE}" rev-parse --short=10 HEAD)-darwin.tar.gz"


#mv build package to root of travis build for artifact upload.
#mv $HOME/build/NREL/export/$oss_filename .

#export ARTIFACTS_PATHS=$oss_filename
# set to 2GB instead of default of 1
#export ARTIFACTS_MAX_SIZE=2147483648 
# supposedly installed by default but not available
#curl -sL https://raw.githubusercontent.com/travis-ci/artifacts/master/install | bash
# TODO don't recreate entire path to file within the AWS bucket.
#artifacts upload
#exit $?
