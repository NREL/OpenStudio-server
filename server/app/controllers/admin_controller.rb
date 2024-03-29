# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class AdminController < ApplicationController
  def index
    require 'rubygems'
    @gems = Gem::Specification.all.map { |g| [g.name, g.version.to_s] }.sort
    #use split.first to remove the --bundle stuff, see why below
    Rails.logger.debug "oscli version command: #{Utility::Oss.oscli_cmd_no_bundle_args(Rails.logger)} openstudio_version"
    # syntax to explicitly unset a bunch of env vars is very different for windows
    # Use the default shell to query for OpenStudio version. Not neccessary to unset these. 
    #unset_vars = Gem.win_platform? || ENV['OS'] == 'Windows_NT' ? 'set ' + Utility::Oss::ENV_VARS_TO_UNSET_FOR_OSCLI.join('= && set ') : 'unset ' + Utility::Oss::ENV_VARS_TO_UNSET_FOR_OSCLI.join(' && unset ')
    oscli_cmd = "#{Utility::Oss.oscli_cmd_no_bundle_args(Rails.logger)} openstudio_version"
    oscli_cmd = "call #{oscli_cmd}" if Gem.win_platform? || ENV['OS'] == 'Windows_NT'
    Rails.logger.debug "oscli_cmd: #{oscli_cmd}"
    version = `#{oscli_cmd}`  #this will not work with --bundle args since user is 'nobody' and cannot create a tmpdir from $HOME
    Rails.logger.debug "oscli version output: #{version}"
    
    @os_cli = version ? version.strip : 'Unknown'
  end

  def backup_database
    logger.info params
    write_and_send_data
  end

  def restore_database
    uploaded_file = params[:file]
    if uploaded_file
      reload_database(uploaded_file)
      redirect_to admin_index_path, notice: "Dropped and Reloaded Database with #{uploaded_file.original_filename}"
    else
      redirect_to admin_index_path, notice: 'No file selected'
    end
  end

  private

  #  http://railscasts.com/episodes/127-rake-in-background
  def call_rake(task, options = {})
    options[:rails_env] ||= Rails.env
    args = options.map { |n, v| "#{n.to_s.upcase}='#{v}'" }
    system "rake #{task} #{args.join(' ')} --trace 2>&1 >> #{Rails.root}/log/rake.log"
  end

  def reload_database(database_file)
    success = false

    extract_dir = "#{APP_CONFIG['rails_tmp_path']}/#{Time.now.to_i}"
    FileUtils.mkdir_p(extract_dir)

    resp = `tar xvzf #{database_file.tempfile.path} -C #{extract_dir}`
    if $?.exitstatus.zero?
      logger.info 'Successfully extracted uploaded database dump'

      exec_str = "mongorestore --username $MONGO_USER --password $MONGO_PASSWORD --authenticationDatabase admin --db #{Mongoid.default_client.database.name} --host #{Mongoid.default_client.cluster.addresses[0].seed} --drop #{extract_dir}/#{Mongoid.default_client.database.name}"
      `#{exec_str}`
      if $?.exitstatus.zero?
        logger.info 'Restored mongo database'
        success = true
      else
        logger.error "Could not restore database with command `#{exec_str}`; erred with exit status of #{$?.exitstatus}"
      end
    end

    success
  end

  def write_and_send_data(file_prefix = 'mongodump')
    success = false

    time_stamp = Time.now.to_i
    dump_dir = "#{APP_CONFIG['rails_tmp_path']}/#{file_prefix}_#{time_stamp}"
    FileUtils.mkdir_p(dump_dir)

    exec_str = "mongodump --username $MONGO_USER --password $MONGO_PASSWORD --authenticationDatabase admin --db #{Mongoid.default_client.database.name} --host #{Mongoid.default_client.cluster.addresses[0].seed} --out #{dump_dir}"
    `#{exec_str}`

    if $?.exitstatus.zero?
      output_file = "#{APP_CONFIG['rails_tmp_path']}/#{file_prefix}_#{time_stamp}.tar.gz"
      `tar czf #{output_file} -C #{dump_dir} #{Mongoid.default_client.database.name}`
      unless $?.exitstatus.zero?
        logger.error "Could not create archive from mongodump; erred with exit status of #{$?.exitstatus}"
        return success
      end
      send_data File.open(output_file).read, filename: File.basename(output_file), type: 'application/targz; header=present', disposition: 'attachment'
      success = true
    else
      logger.error "Could not create mongodump with command `#{exec_str}`; erred with exit status of #{$?.exitstatus}"
    end

    success
  end
end
