require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
#require "active_record/railtie" #mission_control-jobs
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenstudioServer
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1
    config.x.job_manager = :resque
    # Sampling backend for algorithms that support it (currently lhs):
    # :rserve (R via Rserve) or :ruby (pure Ruby, no Rserve required).
    config.x.sampling_backend = (ENV['OS_SERVER_SAMPLING_BACKEND'] || 'rserve').to_sym
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    #config.mission_control.jobs.http_basic_auth_enabled = false  #mission_control-jobs
    #config.mission_control.jobs.adapters = [ :resque ]           #mission_control-jobs
    
    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
