name 'openstudio'
description 'Install and configure OpenStudio and EnergyPlus'

run_list([
  'recipe[openstudio]'
])

default_attributes(
  # Use this for the official release versions
  openstudio: {
    version: '1.9.1',
    installer: {
      version_revision: 'd881f8933e'
    }
  }

# Use this for custom installations from any url
#:openstudio => {
#    :skip_ruby_install => true,
#    :version => "1.5.1",
#    :installer => {
#        :origin => 'url',
#        :version_revision => "5d1f0768a2",
#        :download_url => 'https://github.com/NREL/OpenStudio/releases/download/v1.5.1-workflow5',
#        :download_filename => "OpenStudio-1.5.1.5d1f0768a2-Linux.deb"
#    }
# }
)
