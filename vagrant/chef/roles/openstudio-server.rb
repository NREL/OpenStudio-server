name "openstudio-server"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
            "role[base]",
            "role[ruby]",
            "role[web_base]",
             #"recipe[openstudio]",
             #"recipe[energyplus]",
             #"recipe[R]",
             #"recipe[mongodb::server]",
         ])


default_attributes(


    :openstudio => {
        :version => "0.10.5.11322",
        :checksum => "9180659c77a7fc710cb9826d40ae67c65db0d26bb4bce1a93b64d7e63f4a1f2c"
    },
    :energyplus => {
        :version => "7.2.0.006",
        :checksum => "c1ec1499f964bad8638d3c732c9bd10793dd4052a188cd06bb49288d3d962e09"
    },
    'R' => {
        'apt_distribution' => "precise/",
        'apt_key' => "E084DAB9",
        'package_source_url' => "http://cran.r-project.org/src/contrib",
        'packages' => [
            {
                'name' => 'lhs',
                'version' => '0.10'
            },
            {
                'name' => 'Rserve',
                'version' => '0.6-8.1'
            },
            {
                'name' => 'triangle',
                'version' => '0.8'
            },
            {
                'name' => 'snow',
                'version' => '0.3-12'
            },
            {
                'name' => 'snowfall',
                'version' => '1.84-4'
            }
        ]
    }
)
