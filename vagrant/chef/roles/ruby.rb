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
                           :upgrade => true,
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
                                       :version => "3.2.13",
                                   },
                               ]
                           }
                       },
                   })
