name "radiancet"
description "Installs and configure radiance"


default_attributes()

override_attributes()

run_list([
             "recipe[radiance]",
         ])






