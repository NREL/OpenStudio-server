#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
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
#*******************************************************************************

class AdminController < ApplicationController
  def index
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

  def clear_database
    success_1 = false
    success_2 = false

    logger.info "Working directory is #{Dir.pwd} and I am #{`whoami`}"

    `mongo os_dev --eval "db.dropDatabase();"`
    if $?.exitstatus == 0
      success_1 = true
    end

    # call_rake 'routes' #'db:mongoid:create_indexes'
    # if $?.exitstatus == 0
    #   success_2 = true
    # end

    if success_1 # && success_2
      redirect_to admin_index_path, notice: 'Database deleted successfully.'
    else
      logger.info "Error deleting mongo database: #{success_1}, #{success_2}"
      redirect_to admin_index_path, notice: 'Error deleting database.'
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

    extract_dir = "/tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p(extract_dir)

    resp = `tar xvzf #{database_file.tempfile.path} -C #{extract_dir}`
    if $?.exitstatus == 0
      logger.info 'Successfully extracted uploaded database dump'

      `mongo os_dev --eval "db.dropDatabase();"`
      if $?.exitstatus == 0
        `mongorestore -d os_dev #{extract_dir}/os_dev`
        if $?.exitstatus == 0
          logger.info 'Restored mongo database'
          success = true
        else
          logger.info 'Error trying to reload mongo database'
        end
      end
    end

    success
  end

  def write_and_send_data(file_prefix = 'mongodump')
    success = false

    time_stamp = Time.now.to_i
    dump_dir = "/tmp/#{file_prefix}_#{time_stamp}"
    FileUtils.mkdir_p(dump_dir)

    resp = `mongodump --db os_dev --out #{dump_dir}`

    if $?.exitstatus == 0
      output_file = "/tmp/#{file_prefix}_#{time_stamp}.tar.gz"
      resp_2 = `tar czf #{output_file} -C #{dump_dir} os_dev`
      if $?.exitstatus == 0
        success = true
      end
    end

    if File.exist?(output_file)
      send_data File.open(output_file).read, filename: File.basename(output_file), type: 'application/targz; header=present', disposition: 'attachment'
      success = true
    else
      fail 'could not create dump'
    end

    success
  end
end
