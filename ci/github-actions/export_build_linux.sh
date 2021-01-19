# empty dir for export
mkdir -p $GITHUB_WORKSPACE/build/NREL/export
mkdir -p $HOME/build/NREL/export

export PATH="/usr/loca/bin/ruby:/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin:${PATH}"
export GEM_HOME="$TRAVIS_BUILD_DIR/gems"
export GEM_PATH="$TRAVIS_BUILD_DIR/gems:$TRAVIS_BUILD_DIR/gems/bundler/gems"
# Dir containing openstudio
export RUBYLIB="/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/Ruby"
export OPENSTUDIO_TEST_EXE="/usr/local/openstudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}/bin/openstudio"
mongo_dir="/usr/bin"
/usr/local/ruby/bin/ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --export="HOME/build/NREL/export"
oss_filename="OpenStudio-server-$(git -C "${GITHUB_WORKSPACE}" rev-parse --short=10 HEAD)-linux.tar.gz"
ls -al $HOME/build/NREL/export/
#mv build package to root of travis build for artifact upload.
mv $HOME/build/NREL/export/$oss_filename .
ls -al

# Build the gems and output to tar gz file. You need to specify a dir outside of the repo to export or 
# openstudio_meta will error. Then for sake of using relative dirs with GitHub upload-artifacts, cp the file to
# the repo working directory. 
cp $HOME/build/NREL/export/$oss_filename $GITHUB_WORKSPACE/build/NREL/export/$oss_filename 


