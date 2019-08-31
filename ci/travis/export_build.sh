mkdir "${TRAVIS_BUILD_DIR}/export"
ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="${TRAVIS_BUILD_DIR}/export"
