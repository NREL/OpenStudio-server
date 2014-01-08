#
# Cookbook Name:: openstudio_server
# Recipe:: bashprofile
#
ruby_block "update bash_profile" do
  block do
    bash_filename = "/home/#{node[:openstudio_server][:bash_profile_user]}/.bash_profile"

    if !File.exists?(bash_filename)
      File.open(bash_filename, "w") { |f| f << "# Chef autocreated bash_profile" }
    end

    file = Chef::Util::FileEdit.new(bash_filename)

    file.insert_line_if_no_match(
        "# Useful aliases. Generated by Chef",
        ["\n# Useful aliases. Generated by Chef",
         "alias ls='ls --color=auto'",
         "alias ll='ls -la'",
         "alias l.='ls -d .* --color=auto'",
         "alias ..='cd ..'",
         "alias ...='cd ../../../'",
         "alias ....='cd ../../../../'",
         "alias .....='cd ../../../../'",
         "alias .4='cd ../../../../'",
         "alias .5='cd ../../../../..'",
         "alias grep='grep --color=auto'",
         "alias egrep='egrep --color=auto'",
         "alias fgrep='fgrep --color=auto'",
         "alias path='echo -e ${PATH//:/\\n}'"].join("\n")
    )
    file.write_file

    file.insert_line_if_no_match(
        "# OpenStudio Server aliases. Generated by Chef",
        ["\n# OpenStudio Server aliases. Generated by Chef",
         "alias cs='/data/launch-instance/configure_vagrant_server.sh'",
         "alias cw='/data/launch-instance/configure_vagrant_worker.sh'",
         "alias td='tail -f /var/www/rails/openstudio/log/development.log'",
         "alias tm='tail -f /var/www/rails/openstudio/log/mongo.log'",
         "alias tr='tail -f /var/www/rails/openstudio/log/Rserve.log'",
         "alias cdr='cd /var/www/rails/openstudio'"].join("\n")
    )
    file.write_file

    # Set the permissions on the file
    FileUtils.chown(node[:openstudio_server][:bash_profile_user], node[:openstudio_server][:bash_profile_user], bash_filename)
  end
end
