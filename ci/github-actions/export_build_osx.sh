#empty dir for export
mkdir -p $GITHUB_WORKSPACE/build/NREL/export
mkdir -p $HOME/build/NREL/export


export OS_NAME_WITH_PLUS=OpenStudio-${OPENSTUDIO_VERSION}${OPENSTUDIO_VERSION_EXT}+${OPENSTUDIO_VERSION_SHA}-Darwin-x86_64
export PATH="$GITHUB_WORKSPACE/gems/bin:/usr/local/ruby/bin:$HOME/$OS_NAME_WITH_PLUS/bin:$PATH"
export RUBYLIB="$HOME/$OS_NAME_WITH_PLUS/Ruby"
export GEM_HOME="$GITHUB_WORKSPACE/gems"
export GEM_PATH="$GITHUB_WORKSPACE/gems:$GITHUB_WORKSPACE/gems/bundler/gems"
oss_filename="OpenStudio-server-$(git -C "${GITHUB_WORKSPACE}" rev-parse --short=10 HEAD)-darwin.tar.gz"

# Build the gems and output to tar gz file. You need to specify a dir outside of the repo to export or 
# openstudio_meta will error. Then for sake of using relative dirs with GitHub upload-artifacts, cp the file to
# the repo working directory. 
/usr/local/ruby/bin/ruby "${GITHUB_WORKSPACE}/bin/openstudio_meta" install_gems --export="${HOME}/build/NREL/export"
cp $HOME/build/NREL/export/$oss_filename $GITHUB_WORKSPACE/build/NREL/export/$oss_filename 