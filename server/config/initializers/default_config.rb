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

# Load in the APP_CONFIG
# Read in default config settings unique to this application.
path = File.join(Rails.root, '/config/config.yml')
APP_CONFIG = YAML.load(ERB.new(File.new(path).read).result)[Rails.env]

# Go through and interpret some of the variables
APP_CONFIG['r_scripts_path'] = File.expand_path(APP_CONFIG['r_scripts_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['ruby_bin_dir'] = APP_CONFIG['ruby_bin_dir'].gsub(':ruby_bin_dir', RbConfig::CONFIG['bindir'])
APP_CONFIG['rails_log_path'] = File.expand_path(APP_CONFIG['rails_log_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['rails_tmp_path'] = File.expand_path(APP_CONFIG['rails_tmp_path'].gsub(':rails_root', Rails.root.to_s))

APP_CONFIG['os_server_project_path'] = File.expand_path(APP_CONFIG['os_server_project_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['sim_root_path'] = APP_CONFIG['os_server_project_path'] # TODO: go through the code and rename sim_root_path to os_server_project_path
APP_CONFIG['server_asset_path'] = "#{APP_CONFIG['os_server_project_path']}/server"
APP_CONFIG['max_queued_jobs'] = ENV['OS_SERVER_NUMBER_OF_WORKERS'] if ENV['OS_SERVER_NUMBER_OF_WORKERS']

# Set the default URL
Rails.application.routes.default_url_options[:host] = APP_CONFIG['os_server_host_url'].delete('http://')

# Ensure that the paths exist
FileUtils.mkdir_p APP_CONFIG['os_server_project_path'] unless Dir.exist? APP_CONFIG['os_server_project_path']
FileUtils.mkdir_p "#{APP_CONFIG['os_server_project_path']}/R" unless Dir.exist? "#{APP_CONFIG['os_server_project_path']}/R"
FileUtils.mkdir_p "#{APP_CONFIG['os_server_project_path']}/log" unless Dir.exist? "#{APP_CONFIG['os_server_project_path']}/log"
FileUtils.mkdir_p (APP_CONFIG['server_asset_path']).to_s unless Dir.exist? (APP_CONFIG['server_asset_path']).to_s
FileUtils.mkdir_p "#{APP_CONFIG['server_asset_path']}/R" unless Dir.exist? "#{APP_CONFIG['server_asset_path']}/R"
FileUtils.mkdir_p APP_CONFIG['rails_log_path'] unless Dir.exist? APP_CONFIG['rails_log_path']
FileUtils.mkdir_p APP_CONFIG['rails_tmp_path'] unless Dir.exist? APP_CONFIG['rails_tmp_path']

# update the loggers
Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new("#{APP_CONFIG['rails_log_path']}/#{Rails.env}.log"))

if Rails.application.config.job_manager == :resque
  Resque.logger = Logger.new(File.join(APP_CONFIG['rails_log_path'], 'resque.log'))
  Resque.logger.level = Logger::INFO
end
Mongoid.logger.level = Logger::INFO

# Make sure to add the assets to the asset pipeline
Rails.application.config.assets.paths << "#{APP_CONFIG['server_asset_path']}/assets"

