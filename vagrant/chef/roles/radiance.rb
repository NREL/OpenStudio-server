name 'radiance'
description 'Installs and configure radiance'

default_attributes(
  radiance: {
    version: 'fix-headless'
  }
)

override_attributes

run_list([
  'recipe[radiance]'
])
