name "base"
description "Base role for servers and worker nodes"

run_list([
             # Ensure NREL's root certificate is in place so HTTPS calls will work against
             # NREL's proxy.
             # "recipe[ca_certificates]",

             # Manage the sudoers file
             #"recipe[sudo]",
             #"recipe[sudo::nrel_defaults]",
             #"recipe[sudo::secure_path]",

             # Apt
             "recipe[apt]",

             # Default iptables setup on all servers.
             #"recipe[iptables]",
             #"recipe[iptables::ssh]",
             #"recipe[iptables::icmp_timestamps]",

             #"recipe[curl]",

             # Setup log rotation.
             "recipe[logrotate]",

             # Cron for scheduled tasks.
             "recipe[cron]",

             # Cronic is a handy script to prevent e-mail from over verbose scripts in
             # cron.
             "recipe[cron::cronic]",

             # For checking out our repos.
             "recipe[git]",

             # man pages are handy.
             "recipe[man]",

             # Ensure ntp is used to keep clocks in sync.
             "recipe[ntp]",

             # Use postfix for sending mail.
             #"recipe[postfix]",

             # We want to setup e-mail aliases for the root user by default.
             #"recipe[postfix::aliases]",

             # A much nicer replacement for grep.
             "recipe[ack]",

             # VIM
             "recipe[vim]",

             # Unzip is typically handy to have.
             "recipe[unzip]",

             # Install expect for some advanced scripting
             "recipe[expect]",

             # Secure path
             "recipe[sudo::secure_path]"
         ])

default_attributes(
    # Rotate and compress logs daily by default.
    :logrotate => {
        :frequency => "daily",
        :rotate => 30,
        :compress => true,
        :delaycompress => true,
    },
    :authorization => {
        :sudo => {
            :users => ["vagrant"],
            :include_sudoers_d => true
        }
    },
    :deploy_permissions => {
        :group_members => [
            "vagrant",
        ],
    },
)
