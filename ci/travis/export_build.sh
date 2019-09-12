#empty dir for export
mkdir /Users/travis/build/NREL/export
# path to portable ruby installed in setup.shß
export PATH=$HOME/ruby2.2.4/bin:$PATH
# must be set for gems (esp openstudio-workflow) to find openstudio when install_gems runs install_gems
export RUBYLIB="$HOME/openstudio/Ruby"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="/Users/travis/build/NREL/export"

export ARTIFACTS_PATHS="$(ls /Users/travis/build/NREL/export/*.tar.gz | tr "\n" ":")"
# set to 2GB instead of default of 1
export ARTIFACTS_MAX_SIZE=2147483648 
# supposedly installed by default but not available
curl -sL https://raw.githubusercontent.com/travis-ci/artifacts/master/install | bash
artifacts upload

