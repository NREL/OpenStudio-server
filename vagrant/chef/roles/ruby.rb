name "ruby"
description "The bare essentials for servers that are using ruby."

run_list([
             #"recipe[build-essential]",
             "recipe[ruby_build]",
             "recipe[rbenv::system]",
             "recipe[rbenv::vagrant]",
         ])

default_attributes({
                       :rbenv => {
                           # Don't use the git:// protocol behind our firewall.
                           #:git_url => "https://github.com/sstephenson/rbenv.git",
                           #:git_ref => "v0.4.0",
                           :upgrade => true,
                           #:root_path => "/opt/rbenv",
                           :rubies => ["2.0.0-p195"],
                           :global => "2.0.0-p195",
                           :gems => {
                               "2.0.0-p195" => [
                                   {
                                       :name => "rubygems-bundler",
                                       :version => "1.2.2",
                                   },
                                   {
                                       :name => "rails",
                                       :version => "3.2.13"
                                   },
                                   #{
                                       #:name => "passenger",
                                       #:version => "4.0.0.rc6"
                                   #}
                               ]
                           }
                       },
                   })
