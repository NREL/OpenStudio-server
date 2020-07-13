#empty dir for export
mkdir /Users/travis/build/NREL/export

# must be set for gems (esp openstudio-workflow) to find openstudio when install_gems runs install_gems
export PATH="/usr/local/ruby/bin:$PATH"
export RUBYLIB="$HOME/openstudio/Ruby"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="/Users/travis/build/NREL/export"

oss_filename="OpenStudio-server-${OPENSTUDIO_VERSION_SHA}-darwin.tar.gz"

pip3 install awscli --upgrade --user
aws --version

