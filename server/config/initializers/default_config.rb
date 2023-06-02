# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
