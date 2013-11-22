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
        :build_from_source => true,
        :build_source_url => "http://cran.r-project.org/src/base/R-3",
        :build_version => "3.0.2",
        :apt_key => "E084DAB9",
        :rserve_start_on_boot => false,
        :rserve_user => "vagrant",
        :package_source_url => "http://cran.r-project.org/src/contrib",
        :packages => [
            {
                :name => 'lhs',
                :version => '0.10'
            },
            {
                :name => 'e1071',
                :version => '1.6-1'
            },
            {
                :name => 'Rserve',
                :version => '1.7-3'
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
                :version => '0.0.25'
            },
            {
                :name => 'snow',
                :version => '0.3-13'
            },
            {
                :name => 'snowfall',
                :version => '1.84-4'
            },
            {
                :name => 'R.methodsS3',
                :version => '1.5.2'
            },
            {
                :name => 'R.oo',
                :version => '1.15.8'
            },
            {
                :name => 'R.utils',
                :version => '1.28.4'
            },
            {
                :name => 'iterators',
                :version => '1.0.6'
            },
            {
                :name => 'foreach',
                :version => '1.4.1'
            },
            {
                :name => 'doSNOW',
                :version => '1.0.9'
            },
            {
                :name => 'DEoptim',
                :version => '2.2-2'
            },
            {
                :name => 'NMOF',
                :version => '0.28-2'
            }
        ]
    }
)



