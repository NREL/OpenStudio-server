#!/bin/bash -e

# This script will enable a user to change a single gem in the list of accessible gems. The script will create the
# NEW_GEMFILE_DIR if it does not already exist.

# This script only works with OpenStudio 1.8.0 or newer.
echo "Calling $0 with arguments: $@"

if [[ (-z $1) || (-z $2) || (-z $3) ]]; then
    echo "Expecting script to have 3 parameters:"
    echo "  1: Name of the exiting gem to replace, e.g. openstudio-standards"
    echo "  2: Argument of the new gem GitHub repo, e.g. NREL/openstudio-standards"
    echo "  3: Name of the GitHub branch to install, e.g. master"
    echo "  -- example use: ./set_standards_version.sh /usr/local/openstudio-2.7.1/Ruby openstudio-standards NREL/openstudio-standards master"
    exit 1
fi

# Functions
function replace_gem_in_files (){
  # This method replaces the information needed in `filename`.
  # Args:
    # 1. filepath: path to the location of where the new Gemfile will exist, typically /var/oscli
    # 2. gem_name: name of the gem to replace in the Gemfile, e.g., openstudio-standards
    # 3. gem_repo: name of the new gem that will from github to install, e.g., NREL/openstudio-standards
    # 4. branch: name of the new gem's branch to checkout, e.g., develop
  # Example:
    # Replace  "gem 'openstudio-standards', '= 0.1.15'" with "gem 'openstudio-standards', path: '/var/oscli/clones/openstudio-standards'"

  local filepath=$1
  local gem_name=$2
  local gem_repo=$3
  local branch=$4

  # Clone the new gem with single branch. This can save a lot of time (e.g., openstudio-standards 5m5.393s to 0m51.276s)
  # If the gem has already been checked out, then do a pull.
  mkdir -p $filepath/clones
  if [ -d "$filepath/clones/$gem_name" ]; then
    cd $filepath/clones/$gem_name && git pull
  else
    git clone https://github.com/$gem_repo.git --branch $branch --single-branch $filepath/clones/$gem_name
  fi

  echo "***Replacing gem: $gem_name with version on github under $gem_repo"
  local OLDSTRING="gem '$gem_name'"
  local NEWSTRING="gem '$gem_name', path: '$filepath/clones/$gem_name'"
  if [ ! -f "$filepath/Gemfile" ]; then
    echo "New Gemfile does not exist: ${filepath}/Gemfile"
    exit 1
  fi
  sed -i -e "s|$OLDSTRING.*|$NEWSTRING|g" ${filepath}/Gemfile

  # now replace the openstudio-gems.gemspec version constraint
  if [ ! -f "$filepath/openstudio-gems.gemspec" ]; then
    echo "openstudio-gems.gemspec does not exist: ${filepath}/openstudio-gems.gemspec"
    exit 1
  fi
  local UPDATE_STRING="spec.add_dependency '$gem_name'"
  sed -i -e "s|$UPDATE_STRING.*|$UPDATE_STRING, '>= 0'|g" ${filepath}/openstudio-gems.gemspec
}

# Main

# Find the location of the existing Gemfile based on the contents of the RUBYLIB env variable
echo $(which openstudio)
# You can't call openstudio here since it will load the Server's Gemfile
# echo $(openstudio openstudio_version)
for x in $(printenv RUBYLIB | tr ":" "\n")
do
  if [[ $x =~ .*[Oo]pen[Ss]tudio-[0-9]*\.[0-9]*\.[0-9]*/Ruby ]]; then
    GEMFILE_DIR=$x
    continue
  fi
done

echo "GEMFILE_DIR is set to $GEMFILE_DIR"
NEW_GEMFILE_DIR=/var/oscli
EXISTING_GEM=$1
NEW_GEM_REPO=$2
NEW_GEM_BRANCH=$3
GEMFILEUPDATE=$NEW_GEMFILE_DIR/analysis_$SCRIPT_ANALYSIS_ID.lock

# First check if there is a file that indicates the gem has already been updated.
# We only need to update the bundle once / worker, not every time a data point is initialized.
echo "Checking if Gemfile has been updated in ${GEMFILEUPDATE}"
if [ -e $GEMFILEUPDATE ]; then
    echo "***The gem bundle has already been updated"
    exit 0
fi

# Determine the version of Bundler and make sure it is installed
if [ -e ${GEMFILE_DIR}/Gemfile.lock ]; then
  LOCAL_BUNDLER_VERSION=$(tail -n 1 ${GEMFILE_DIR}/Gemfile.lock | tr -dc '[0-9.]')
  echo "Installing Bundler version $LOCAL_BUNDLER_VERSION"
  if [ -z $LOCAL_BUNDLER_VERSION ]; then
    echo "Could not determine version of Bundler to use from Gemfile.lock"
  fi
   gem install --install-dir /var/oscli/gems/ruby/2.5.0 bundler -v $LOCAL_BUNDLER_VERSION
#   gem install bundler -v $LOCAL_BUNDLER_VERSION
else
  echo "Could not find Gemfile.lock file in $GEMFILE_DIR"
  exit 1
fi

# Verify the path of the required files
if [ ! -d "$GEMFILE_DIR" ]; then
  echo "Directory for Gemfile does not exist: ${GEMFILE_DIR}"
  exit 1
fi

if [ ! -f "$GEMFILE_DIR/Gemfile" ]; then
  echo "Gemfile does not exist in: ${GEMFILE_DIR}"
  exit 1
fi

if [ ! -f "$GEMFILE_DIR/openstudio-gems.gemspec" ]; then
  echo "openstudio-gems.gemspec does not exist in: ${GEMFILE_DIR}"
  echo "!!! This script only works with OpenStudio 2.8.0 and newer !!!"
  exit 1
fi



# Modify the reference Gemfile and gemspec in place
mkdir -p $NEW_GEMFILE_DIR
cp $GEMFILE_DIR/Gemfile $NEW_GEMFILE_DIR
cp $GEMFILE_DIR/openstudio-gems.gemspec $NEW_GEMFILE_DIR

replace_gem_in_files $NEW_GEMFILE_DIR $EXISTING_GEM $NEW_GEM_REPO $NEW_GEM_BRANCH

# Pull the workflow gem from develop otherwise `require 'openstudio-workflow'` fails, supposedly
#replace_gem_in_files $NEW_GEMFILE_DIR 'openstudio-workflow' 'NREL/openstudio-workflow-gem' 'develop'

# Show the modified Gemfile contents in the log
cd $NEW_GEMFILE_DIR
dos2unix $NEW_GEMFILE_DIR/Gemfile
#echo "gem 'pycall'" >> Gemfile 
dos2unix $NEW_GEMFILE_DIR/openstudio-gems.gemspec
echo "***Here are the modified Gemfile and openstudio-gems.gemspec files:"
cat $NEW_GEMFILE_DIR/Gemfile
cat $NEW_GEMFILE_DIR/openstudio-gems.gemspec

# Unset all BUNDLE, GEM, and RUBY environment variables before calling bundle install. These
# are required before re-bundling!
for evar in $(env | cut -d '=' -f 1 | grep ^BUNDLE); do unset $evar; done
for evar in $(env | cut -d '=' -f 1 | grep ^GEM); do unset $evar; done
for evar in $(env | cut -d '=' -f 1 | grep ^RUBY); do unset $evar; done
export RUBYLIB=$GEMFILE_DIR:/usr/Ruby:$RUBYLIB

# Update the specified gem in the bundle
echo "***Running bundle install with version $LOCAL_BUNDLER_VERSION in $(which bundle)"
if [ -f Gemfile.lock ]; then
  rm Gemfile.lock
fi
bundle '_'$LOCAL_BUNDLER_VERSION'_' install --path gems --verbose

# Note that the bundle has been updated
echo >> $GEMFILEUPDATE
