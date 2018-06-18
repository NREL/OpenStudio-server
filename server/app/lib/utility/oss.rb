module Utility
  class Oss
    # Run script identified by full_path.  Set timeout unless nil
    def self.run_script full_path, timeout = nil, env_vars = {}, logger = Rails.logger
      begin
        logger.info "updating permissions for #{full_path}"
        File.chmod(0755, full_path) #755
        logger.info "running #{full_path}"

        # Spawn the process and wait for completion. Note only the specified env vars are available in the subprocess
        # todo handle nil timeout - don't interrupt
        # todo consider passing log
        pid = spawn(env_vars, full_path, :unsetenv_others => true)
        Timeout.timeout(timeout) do
          Process.wait pid
        end
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