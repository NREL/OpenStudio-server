name "ruby"
description "The bare essentials for servers that are using ruby."

run_list([
             #"recipe[build-essential]",
             "recipe[ruby_build]",
             "recipe[rbenv::system]",
         #"recipe[rbenv::vagrant]",
         ])

default_attributes(
    :rbenv => {
        :upgrade => true,
        :rubies => [
            {
                :name => '2.0.0-p195',
                :environment => {
                    'RUBY_CONFIGURE_OPTS' => '--enable-shared', # needs to be set for openstudio linking
                    'CONFIGURE_OPTS' => '--disable-install-doc'
                }
            }
        ],
        :no_rdoc_ri => true,
        :global => "2.0.0-p195",
        :gems => {
            "2.0.0-p195" => [
                {
                    :name => "mongoid"
                },
                {
                    :name => "mongoid-paperclip"
                },
                {
                    :name => "libxml-ruby"
                },
                {
                    :name => "zip"
                },
                {
                    :name => "delayed_job_mongoid"
                },
                {
                    :name => "net-http-persistent"
                },
                {
                    :name => "net-ssh"
                },
                {
                    :name => "net-scp"
                },
                {
                    :name => "net-scp"
                },
                {
                    :name => "ruby-prof"
                }
            ]
        }
    }

)
