name "r-project"
description "Installs and configure R"

run_list([
             "recipe[java]",
             "recipe[R]",
         ])


default_attributes(
    :java => {
        :set_java_home => false
    },
    :R => {
        :apt_distribution => "precise/",
        :apt_key => "E084DAB9",
        :package_source_url => "http://cran.r-project.org/src/contrib",
        :packages => [
            {
                :name => 'lhs',
                :version => '0.10'
            },
            {
                :name => 'Rserve',
                :version => '1.7-2'
            },
            {
                :name => 'triangle',
                :version => '0.8'
            },
            {
                :name => 'rJava',
                :version => '0.9-4'
            },
            {
                :name => 'RUnit',
                :version => '0.4.26'
            },
            {
                :name => 'RMongo',
                :version => '0.0.23'
            },
            {
                :name => 'snow',
                :version => '0.3-12'
            },
            {
                :name => 'snowfall',
                :version => '1.84-4'
            }
        ]
    }
)



