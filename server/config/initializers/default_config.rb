# Read in default config settings unique to this application.

APP_CONFIG = YAML.load_file(File.join(Rails.root,'/config/config.yml'))[Rails.env]

# Go through and interpret some of the variables
APP_CONFIG['sim_root_path'] = File.expand_path(APP_CONFIG['sim_root_path'].gsub(':rails_root', Rails.root.to_s))

