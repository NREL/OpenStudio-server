name "r-project"
description "Installs and configure R"

run_list([
             "recipe[R]",
         ])


default_attributes(
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
