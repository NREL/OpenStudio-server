name 'openstudio'
description 'Install and configure OpenStudio and EnergyPlus'

run_list([
  'recipe[openstudio]'
])

default_attributes(
#   Use this for the official release versions
#   openstudio: {
#     version: '1.9.4',
#     installer: {
#       version_revision: '89da90eab8'
#     }
#   }

# Use this for custom installations from any url
  openstudio: {
    skip_ruby_install: true,
    version: "1.9.4",
    installer: {
      origin: 'url',
      download_url: 'https://openstudio-builds.s3.amazonaws.com/1.9.4',
      download_filename: "OpenStudio-1.9.4.89da90eab8-Linux.deb"
    }
  }
)
