name "radiance"
description "Installs and configure radiance"


default_attributes(
    :radiance => {
        :version => '4.2'
    }
)

override_attributes()

run_list([
             "recipe[radiance]",
         ])








