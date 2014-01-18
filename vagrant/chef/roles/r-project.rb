name "r-project"
description "install r"

default_attributes(
    :r => {
        :install_repo => false,
        :install_method => "source",
        :add_r_to_path => true,
        :add_ld_path => true,
        :prefix_bin => "/usr/local/bin",
        :make_opts => ["-j4"],
        :libraries => [
            {
                :name => "snow"
            },
            {
                :name => "Rserve"
            },
            {
                :name => "lhs"
            },
            {
                :name => "e1071"
            },
            {
                :name => "triangle"
            },
            {
                :name => "rJava"
            },
            {
                :name => "RUnit"
            },
            {
                :name => "RMongo"
            },
            {
                :name => "snowfall"
            },
            {
                :name => "R.methodsS3"
            },
            {
                :name => "R.oo"
            },
            {
                :name => "R.utils"
            },
            {
                :name => "iterators"
            },
            {
                :name => "foreach"
            },
            {
                :name => "doSNOW"
            },
            {
                :name => "DEoptim"
            },
            {
                :name => "NMOF"
            },
            {
                :name => "mco"
            },
            {
                :name => "rjson"
            },
            {
                :name => "rgenoud"
            },
            {
                :name => "snowFT"
            },
            {
                :name => 'NRELmoo',
                :package_path => "/data/R-packages",
                :version => '1.1.3'
            },
            {
                :name => 'Swift',
                :package_path => "/data/R-packages",
                :version => '0.3.1'
            },
            {
                :name => 'NRELsnowFT',
                :package_path => "/data/R-packages",
                :version => '1.3.32'
            }
        ]
    }
)

override_attributes(
    :r => {
        :config_opts => ["--enable-R-shlib"] # build with x11 support (removes "--with-x=no",)
    }
)

run_list(
    [
        "recipe[java]",
        "recipe[r::default]",
        "recipe[r::rserve]",
    ])

