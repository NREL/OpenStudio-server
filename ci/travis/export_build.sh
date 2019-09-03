mkdir "${TRAVIS_BUILD_DIR}/export"
# path to portable ruby installed in setup.shß
export PATH=$HOME/ruby2.2.4/bin:$PATH
ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="${TRAVIS_BUILD_DIR}/export"
