# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Base class for all analyses. These methods need to be independent of R.
# If a method is needed from R, then include AnalysisLibrary::R::Core

module AnalysisLibrary
  class Base
    include AnalysisLibrary::Core

    # Since this is a delayed job, if it crashes it will typically try multiple times.
    # Fix this to 1 retry for now.
    def max_attempts
      1
    end

    # Return the logger for the worker
    def logger
      # Ternaries handle loggers with running without delayed_jobs or resque (without_delay)
      if Rails.application.config.job_manager == :delayed_job
        Delayed::Worker.logger || Logger.new(STDOUT)
      elsif Rails.application.config.job_manager == :resque
        Resque.logger || Logger.new(STDOUT)
      else
        raise 'Rails.application.config.job_manager must be set to :resque or :delayed_job'
      end
    end

    # Return the Ruby system call string for ease
    def sys_call_ruby
      "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/ruby"
    end

    def analysis_dir(id)
      "#{APP_CONFIG['sim_root_path']}/analysis_#{id}"
    end
  end
end
