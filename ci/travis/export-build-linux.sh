# path to portable ruby installed in setup.shß
export PATH="${HOME}/.rbenv/versions/2.2.4/bin:/usr/local/openstudio-${OPENSTUDIO_VERSION}/bin:${PATH}"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
# Dir containing openstudio
export RUBYLIB="/usr/local/openstudio-${OPENSTUDIO_VERSION}/Ruby:/usr/Ruby"
export OPENSTUDIO_TEST_EXE="/usr/local/openstudio-${OPENSTUDIO_VERSION}/bin/openstudio"
mongo_dir="/usr/bin"
# empty dir for export
mkdir /home/travis/build/NREL/export

ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="/home/travis/build/NREL/export"

export ARTIFACTS_PATHS="$(ls /home/travis/build/NREL/export/*.tar.gz | tr "\n" ":")"
# set to 2GB instead of default of 1
export ARTIFACTS_MAX_SIZE=2147483648 
# supposedly installed by default but not available
curl -sL https://raw.githubusercontent.com/travis-ci/artifacts/master/install | bash
# TODO don't recreate entire path to file within the AWS bucket.
artifacts upload