# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

class AdminController < ApplicationController
  def index
    require 'rubygems'
    @gems = Gem::Specification.all.map { |g| [g.name, g.version.to_s] }.sort

    @os_cli = `openstudio openstudio_version`.strip
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

      exec_str = "mongorestore -d #{Mongoid.default_client.database.name} -h #{Mongoid.default_client.cluster.addresses[0].seed} --drop #{extract_dir}/#{Mongoid.default_client.database.name}"
      `#{exec_str}`
      if $?.exitstatus.zero?
        logger.info 'Restored mongo database'
        success = true
      else
        logger.info "Could not restore database with command `#{exec_str}`; erred with exit status of #{$?.exitstatus}"
      end
    end

    success
  end

  def write_and_send_data(file_prefix = 'mongodump')
    success = false

    time_stamp = Time.now.to_i
    dump_dir = "#{APP_CONFIG['rails_tmp_path']}/#{file_prefix}_#{time_stamp}"
    FileUtils.mkdir_p(dump_dir)

    exec_str = "mongodump --db #{Mongoid.default_client.database.name} --host #{Mongoid.default_client.cluster.addresses[0].seed} --out #{dump_dir}"
    `#{exec_str}`

    if $?.exitstatus.zero?
      output_file = "#{APP_CONFIG['rails_tmp_path']}/#{file_prefix}_#{time_stamp}.tar.gz"
      `tar czf #{output_file} -C #{dump_dir} #{Mongoid.default_client.database.name}`
      unless $?.exitstatus.zero?
        logger.info "Could not create archive from mongodump; erred with exit status of #{$?.exitstatus}"
        return success
      end
      send_data File.open(output_file).read, filename: File.basename(output_file), type: 'application/targz; header=present', disposition: 'attachment'
      success = true
    else
      logger.info "Could not create mongodump with command `#{exec_str}`; erred with exit status of #{$?.exitstatus}"
    end

    success
  end
end
