# Load in the APP_CONFIG
# Read in default config settings unique to this application.
path = File.join(Rails.root, '/config/config.yml')
APP_CONFIG = YAML.load(ERB.new(File.new(path).read).result)[Rails.env]

# Go through and interpret some of the variables
APP_CONFIG['sim_root_path'] = File.expand_path(APP_CONFIG['sim_root_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['ruby_bin_dir'] = APP_CONFIG['ruby_bin_dir'].gsub(':ruby_bin_dir', RbConfig::CONFIG['bindir'])
APP_CONFIG['rails_log_path'] = File.expand_path(APP_CONFIG['rails_log_path'].gsub(':rails_root', Rails.root.to_s))
APP_CONFIG['server_asset_path'] = File.expand_path(APP_CONFIG['server_asset_path'].gsub(':rails_root', Rails.root.to_s))

# Set the default URL
Rails.application.routes.default_url_options[:host] = APP_CONFIG['os_server_host_url'].delete("http://")

# Set the log path
FileUtils.mkdir_p APP_CONFIG['server_asset_path'] unless Dir.exist? APP_CONFIG['server_asset_path']
FileUtils.mkdir_p "#{APP_CONFIG['server_asset_path']}/R" unless Dir.exist? "#{APP_CONFIG['server_asset_path']}/R"
FileUtils.mkdir_p APP_CONFIG['rails_log_path'] unless Dir.exist? APP_CONFIG['rails_log_path']
Rails.logger = Logger.new "#{APP_CONFIG['rails_log_path']}/#{Rails.env}.log"
