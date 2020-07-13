#empty dir for export
mkdir /Users/travis/build/NREL/export

export PATH="/usr/local/ruby/bin:$PATH"
export RUBYLIB="$HOME/openstudio/Ruby"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="/Users/travis/build/NREL/export"
oss_filename="OpenStudio-server-$(git -C "${TRAVIS_BUILD_DIR}" rev-parse --short=10 HEAD)-darwin.tar.gz"


#mv build package to root of travis build for artifact upload.
mv /Users/travis/build/NREL/export/$oss_filename .

export ARTIFACTS_PATHS=$oss_filename
# set to 2GB instead of default of 1
export ARTIFACTS_MAX_SIZE=2147483648 
# supposedly installed by default but not available
curl -sL https://raw.githubusercontent.com/travis-ci/artifacts/master/install | bash
# TODO don't recreate entire path to file within the AWS bucket.
artifacts upload

