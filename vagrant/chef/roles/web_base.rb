name "buildingagent_web_base"
description "A base role for buildingagent web servers."

run_list([
             "role[base]",
             "role[ruby]",

             "recipe[apache2]",
             "recipe[apache2::mod_rewrite]",
             "recipe[apache2::mod_ssl]",
             "recipe[apache2::iptables]",
             "role[passenger_apache]",

         "recipe[openstudio_server]"
         #"recipe[buildingagent::web]",

         #"recipe[deploy_permissions]",
         #"recipe[deploy_permissions::apache]",
         #"recipe[deploy_permissions::whenever]",
         ])

override_attributes({
                        :apache => {
                            :listen_ports => ["80", "443"],
                        },

                    })
