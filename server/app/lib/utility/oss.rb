module Utility
  class Oss
    # this list should match the env vars unset in the extension gem runner: 
    # https://github.com/NREL/openstudio-extension-gem/blob/develop/lib/openstudio/extension/runner.rb#L155
    ENV_VARS_TO_UNSET_FOR_OSCLI = [
      'BUNDLE_GEMFILE',
      'BUNDLE_PATH',
      'RUBYLIB',
      'RUBYOPT',
      'BUNDLE_BIN_PATH',
      'BUNDLER_VERSION',
      'BUNDLER_ORIG_PATH',
      'BUNDLER_ORIG_MANPATH',
      'GEM_PATH',
      'GEM_HOME',
      'BUNDLE_GEMFILE',
      'BUNDLE_PATH',
      'BUNDLE_WITHOUT'
    ]
    # return command to run openstudio cli on current platform
    def self.oscli_cmd(logger = Rails.logger)
      # determine if an explicit oscli path has been set via the meta-cli option, warn if not

      raise 'OPENSTUDIO_EXE_PATH not set' unless ENV['OPENSTUDIO_EXE_PATH']
      raise "Unable to find file specified in OPENSTUDIO_EXE_PATH: `#{ENV['OPENSTUDIO_EXE_PATH']}`" unless File.exist?(ENV['OPENSTUDIO_EXE_PATH'])

      # set cmd from ENV variable
      cmd = ENV['OPENSTUDIO_EXE_PATH']
    rescue Exception => e
      logger.warn "Error finding Oscli: #{e}"
      cmd = Gem.win_platform? || ENV['OS'] == 'Windows_NT' ? 'openstudio.exe' : `which openstudio`.strip
      if File.exist?(cmd)
        logger.warn "Defaulting to fun Oscli via #{cmd}"
      else
        logger.error 'Unable to find Oscli.'
      end
      logger.info "Returning Oscli cmd: #{cmd + oscli_bundle}"
      cmd + oscli_bundle
    end

    # use bundle option only if we have a path to openstudio gemfile.
    # if BUNDLE_PATH is not set (ie Docker), we must add these options
    def self.oscli_bundle
      bundle = Rails.application.config.os_gemfile_path.present? ? ' --bundle '\
      "#{File.join Rails.application.config.os_gemfile_path, 'Gemfile'} --bundle_path "\
      "#{File.join Rails.application.config.os_gemfile_path, 'gems'} " : ''
    end

    # Set some env_vars from the running env var list, ignore the rest
    #
    # Why are these all class methods?
    def self.resolve_env_vars(env_vars)
      # List of items to keep as regex.
      # 4/19/2019 Keep rbenv related env vars for when running locally
      keep_starts_with = [/^RUBY/, /^BUNDLE/, /^GEM/, /^RAILS_ENV/, /PATH/, /^RBENV/]

      new_env_vars = {}
      ENV.each do |var, value|
        if keep_starts_with.find { |regex| var =~ regex }
          new_env_vars[var] = value
        end
      end

      # add and/or overwrite any custom env vars
      env_vars.each do |var, value|
        new_env_vars[var] = value
      end

      new_env_vars
    end

    # Load args from file.  Returns array or nil.
    def self.load_args(full_path)
      args_array = JSON.parse(File.read(full_path))
      # if not array, ignore file contents and return nil
      (args_array.is_a? Array) ? args_array : nil
    end

    # Run script identified by full_path.
    #
    # Note that if the spawned_log_path is nil, then this will not execute!
    def self.run_script(full_path, timeout = nil, env_vars = {}, args_array = nil, logger = Rails.logger, spawned_log_path = nil)
      logger.debug "updating permissions for #{full_path}"
      File.chmod(0o755, full_path) # 755
      logger.debug "removing DOS endings for #{full_path}"
      file_text = File.read(full_path)
      file_text.gsub!(/\r\n/m, "\n")
      File.open(full_path, 'wb') { |f| f.print file_text }

      logger.debug "running #{full_path}"
      # Spawn the process and wait for completion. Note only the specified env vars are available in the subprocess
      # TODO: handle nil timeout - don't interrupt

      # grab some env vars out of the system env vars in order to run rails runner.
      env_vars = Utility::Oss.resolve_env_vars(env_vars)

      pid = spawn(env_vars, full_path, *args_array, [:out, :err] => spawned_log_path, :unsetenv_others => true)
      Timeout.timeout(timeout) do
        Process.wait pid
      end
      exit_code = $?.exitstatus
      logger.debug "Script returned with exit code #{exit_code} of class #{exit_code.class}"
      raise "Script file #{full_path} returned with non-zero exit code. See #{spawned_log_path}." unless exit_code == 0

      return true
    rescue Timeout::Error
      logger.error "Killing script #{fullpath} due to timeout after #{timeout} seconds."
      Process.kill('TERM', pid)
      return false
    rescue Exception => e
      logger.error "Script #{full_path} resulted in error #{e}"
      return false
    end
  end
end
