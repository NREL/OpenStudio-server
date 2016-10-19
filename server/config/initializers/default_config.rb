# Load in the APP_CONFIG
# Read in default config settings unique to this application.
path = File.join(Rails.root, '/config/config.yml')
APP_CONFIG = YAML.load(ERB.new(File.new(path).read).result)[Rails.env]

# Go through and interpret some of the variables

APP_CONFIG['r_scripts_path'] = File.expand_path(APP_CONFIG['r_scripts_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['ruby_bin_dir'] = APP_CONFIG['ruby_bin_dir'].gsub(':ruby_bin_dir', RbConfig::CONFIG['bindir'])
APP_CONFIG['rails_log_path'] = File.expand_path(APP_CONFIG['rails_log_path'].gsub(':rails_root', Rails.root.to_s))

# APP_CONFIG['server_asset_path'] = File.expand_path(APP_CONFIG['server_asset_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['os_server_project_path'] = File.expand_path(APP_CONFIG['os_server_project_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['sim_root_path'] = APP_CONFIG['os_server_project_path'] # TODO: go through the code and rename sim_root_path to os_server_project_path
APP_CONFIG['server_asset_path'] = "#{APP_CONFIG['os_server_project_path']}/server"

# Set the default URL
Rails.application.routes.default_url_options[:host] = APP_CONFIG['os_server_host_url'].delete('http://')

# Ensure that the paths exist
FileUtils.mkdir_p APP_CONFIG['os_server_project_path'] unless Dir.exist? APP_CONFIG['os_server_project_path']
FileUtils.mkdir_p "#{APP_CONFIG['os_server_project_path']}/R" unless Dir.exist? "#{APP_CONFIG['os_server_project_path']}/R"
FileUtils.mkdir_p (APP_CONFIG['server_asset_path']).to_s unless Dir.exist? (APP_CONFIG['server_asset_path']).to_s
FileUtils.mkdir_p APP_CONFIG['rails_log_path'] unless Dir.exist? APP_CONFIG['rails_log_path']

# Enable the rails middleware to access files in the `server_asset_path` as
# well.
Rails.application.config.middleware.insert_after(
  ActionDispatch::Static,
  ActionDispatch::Static,
  Rails.root.join(APP_CONFIG['server_asset_path']).to_s,
  Rails.application.config.static_cache_control
)

# update the loggers
Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new("#{APP_CONFIG['rails_log_path']}/#{Rails.env}.log"))
Mongoid.logger.level = Logger::INFO
