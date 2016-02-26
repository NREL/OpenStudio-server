# Read in default config settings unique to this application.

APP_CONFIG = YAML.load_file(File.join(Rails.root,'/config/config.yml'))[Rails.env]

