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

    # Return the logger for the delayed job
    def logger
      Delayed::Worker.logger
    end

    # Return the Ruby system call string for ease
    def sys_call_ruby
      "cd #{APP_CONFIG['sim_root_path']} && #{APP_CONFIG['ruby_bin_dir']}/ruby"
    end
  end
end
