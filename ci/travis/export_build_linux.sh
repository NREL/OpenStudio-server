# empty dir for export
mkdir /home/travis/build/NREL/export

export PATH="/usr/loca/bin/ruby:/usr/local/openstudio-${OPENSTUDIO_VERSION}/bin:${PATH}"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
# Dir containing openstudio
export RUBYLIB="/usr/local/openstudio-${OPENSTUDIO_VERSION}/Ruby"
export OPENSTUDIO_TEST_EXE="/usr/local/openstudio-${OPENSTUDIO_VERSION}/bin/openstudio"
mongo_dir="/usr/bin"
/usr/local/ruby/bin/ruby "${TRAVIS_BUILD_DIR}/bin/openstudio_meta" install_gems --export="/home/travis/build/NREL/export"
oss_filename="OpenStudio-server-$(git -C "${TRAVIS_BUILD_DIR}" rev-parse --short=10 HEAD)-linux.tar.gz"
ls -al /home/travis/build/NREL/export/
#mv build package to root of travis build for artifact upload.
mv /home/travis/build/NREL/export/$oss_filename .
ls -al

export ARTIFACTS_PATHS=$oss_filename
# set to 2GB instead of default of 1
export ARTIFACTS_MAX_SIZE=2147483648 
# supposedly installed by default but not available
curl -sL https://raw.githubusercontent.com/travis-ci/artifacts/master/install | bash
# TODO don't recreate entire path to file within the AWS bucket.
artifacts upload
exit $?

