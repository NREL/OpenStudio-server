name 'radiance'
description 'Installs and configure radiance'

default_attributes(
  radiance: {
    version: '5.0.a.8'
  }
)

override_attributes

run_list([
  'recipe[radiance]'
])
