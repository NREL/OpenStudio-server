require File.expand_path('../boot', __FILE__)

# require 'rails/all'
# require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenstudioServer
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths << Rails.root.join('lib')

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Set the queue adapter
    # config.active_job.queue_adapter = :delayed_job

    # custom config var which will be overriden in environment file for environments that use :delayed_job
    config.job_manager = :resque

    # if present, will be used with --bundle option in calls to OpenStudio CLI
    config.os_gemfile_path = nil

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true

    # remove x-frame-options header
    config.action_dispatch.default_headers.delete('X-Frame-Options')


    # Rails 5 upgrade additions
    # ActiveSupport.halt_callback_chains_on_return_false = false
  end
end
