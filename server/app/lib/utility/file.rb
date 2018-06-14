module Utility
  class File
    # Run script identified by full_path.  Set timeout unless nil
    def self.run_script full_path, timeout = nil, env_vars = {}, logger = Rails.logger
      begin
        logger.info "updating permissions for #{init_file_path}"
        File.chmod(0777, init_file_path)
        logger.info "running #{init_file_path}"

        # Spawn the process and wait for completion. Note only the specified env vars are available in the subprocess
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