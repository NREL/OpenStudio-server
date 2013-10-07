name "openstudio-server"
description "Install and configure OpenStudio for use with Ruby on Rails"

run_list([
             # Default iptables setup on all servers.
             "role[base]",
             "role[ruby]",
             "role[r-project]",
             "recipe[mongodb::server]",
             "role[openstudio]",
             "role[web_base]",
             "recipe[openstudio_server::bundle]", #install the bundle first to get rails for apache passenger
             "role[passenger_apache]",
             "recipe[openstudio_server]",
         ])


default_attributes(
    :openstudio_server => {
        :ruby_path => "/usr/local/rbenv", # this is needed for the delayed_job service
        :server_path => "/var/www/rails/openstudio",
        :rails_environment => "development"
    }
)

override_attributes(
    :R => {
        :rserve_start_on_boot => true,
        :rserve_user => "ubuntu",
        :rserve_log_path => "/var/www/rails/openstudio/log/Rserve.log"
    }
)
