# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'delayed_job'

if ['local', 'local-test'].include? Rails.env
  # Allow the jobs to run for up to 1 week.  If this is ever hit, then we have other problems.
  # Delayed::Worker.destroy_failed_jobs = false
  # Delayed::Worker.sleep_delay = 60
  # Delayed::Worker.max_attempts = 3

  Delayed::Worker.max_run_time = 168.hours
  # Delayed::Worker.read_ahead = 10
  # Delayed::Worker.default_queue_name = 'default'
  # Delayed::Worker.delay_jobs = !Rails.env.test?
  Delayed::Worker.raise_signal_exceptions = :term
  Delayed::Worker.logger = Logger.new(File.join(APP_CONFIG['rails_log_path'], 'delayed_job.log'))

  # Delayed::Worker.plugins << Delayed::TaggedLogging::Plugin
end
