module Utility
  class Oss

    # Load args from file.  Returns array or nil.
    def self.load_args full_path
      args_array = JSON.parse(File.read(full_path))
      # if not array, ignore file contents and return nil
      (args_array.kind_of? Array) ? args_array : nil
    end

    # Run script identified by full_path.
    def self.run_script full_path, timeout = nil, env_vars = {}, args_array = nil, logger = Rails.logger, spawned_log_path = nil
      begin
        logger.debug "updating permissions for #{full_path}"
        File.chmod(0755, full_path) #755
        logger.debug "removing DOS endings for #{full_path}"
        file_text = File.read(full_path)
        file_text.gsub!(/\r\n/m, "\n")
        File.open(full_path, 'wb') { |f| f.print file_text }

        logger.debug "running #{full_path}"
        # Spawn the process and wait for completion. Note only the specified env vars are available in the subprocess
        # todo handle nil timeout - don't interrupt
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
      rescue Exception=>e
        logger.error "Script #{full_path} resulted in error #{e}"
        return false
      end
    end
  end
end