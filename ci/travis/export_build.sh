mkdir "${TRAVIS_BUILD_DIR}/export"
# path to portable ruby installed in setup.shß
export PATH=$HOME/ruby2.2.4/bin:$PATH
# must be set for gems (esp openstudio-workflow) to find openstudio when install_gems runs install_gems
export RUBYLIB="$HOME/openstudio/Ruby"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="${TRAVIS_BUILD_DIR}/export"
