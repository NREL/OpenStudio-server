OpenstudioServer::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.cache_classes = true

  # Configure static asset server for local with Cache-Control for performance
  config.serve_static_assets = true
  config.static_cache_control = 'public, max-age=3600'

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in local environment
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # Rails log path
  config.log_path = ENV['RAILS_LOGFILE']

end
