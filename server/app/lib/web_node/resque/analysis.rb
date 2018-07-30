# Functions required by Analysis class when running on Web in environment that leverages Resque
module WebNode
  module Resque
    module Analysis
      # path to analysis in osdata volume
      def shared_directory_path
        "#{APP_CONFIG['server_asset_path']}/analyses/#{id}"
      end
      # Unpack analysis.zip into the osdata volume for use by background and web
      # specific usecase is to run analysis initialization and finalization scripts.
      # currently only used with Resque, as it's called by ResqueJobs::InitializeAnalysis job
      # runs on web node
      def run_initialization
        #   unpack seed zip file into osdata
        #   run initialize.sh if present
        # Extract the zip
        extract_count = 0
        extract_max_count = 3
        logger.info "Running analysis initialization scripts"
        logger.info "Extracting seed zip #{seed_zip.path} to #{shared_directory_path}"
        begin
          Timeout.timeout(180) do
            extract_count += 1
            OpenStudio::Workflow.extract_archive(seed_zip.path, shared_directory_path)
          end
        rescue => e
          retry if extract_count < extract_max_count
          raise "Extraction of the seed.zip file failed #{extract_max_count} times with error #{e.message}"
        end
        run_script_with_args "initialize"
     end

      # runs on web node
      def run_finalization
        logger.info "Running analysis finalization scripts"
        run_script_with_args "finalize"
      end

      private

      def run_script_with_args script_name
        dir_path = "#{shared_directory_path}/scripts/analysis"
        #  paths to check for args and script files
        args_path = "#{dir_path}/#{script_name}.args"
        script_path = "#{dir_path}/#{script_name}.sh"
        log_path = "#{dir_path}/#{script_name}.log"

        logger.info "Checking for presence of args file at #{args_path}"
        args = nil
        if File.file? args_path
          args = Utility::Oss.load_args args_path
          logger.info " args loaded from file #{args_path}: #{args}"
        end


        logger.info "Checking for presence of script file at #{script_path}"
        if File.file? script_path
          # TODO how long do we want to set timeout?
          # SCRIPT_PATH - path to where the scripts were extracted
          # HOST_URL - URL of the server
          # RAILS_ROOT - location of rails
          Utility::Oss.run_script(script_path, 4.hours, {'SCRIPT_PATH' => dir_path, 'ANALYSIS_ID' => id, 'HOST_URL' => APP_CONFIG['os_server_host_url'], 'RAILS_ROOT' => Rails.root.to_s, 'ANALYSIS_DIRECTORY' => shared_directory_path}, args, logger,log_path)
        end
      end
    end
  end
end