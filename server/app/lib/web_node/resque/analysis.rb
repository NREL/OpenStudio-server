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

        #   check for presence of analysis initialization script and if present
        file_path = "#{shared_directory_path}/scripts/analysis/initialize.sh"
        logger.info "Checking for presence of initialization file at #{file_path}"
        if File.file? file_path
          # TODO how long do we want to set timeout?
          Utility::File.run_script(file_path, 60*60*4, {'ANALYSIS_ID' => id}, logger)
        end
     end

      # runs on web node
      def run_finalization
        logger.info "running finalization method for #{id}"
        #   check for presence of analysis finalizaiton script and if present
        file_path = "#{shared_directory_path}/scripts/analysis/finalize.sh"
        logger.info "Checking for presence of initialization file at #{init_file_path}"
        if File.file? ifile_path
          # TODO how long do we want to set timeout?
          Utility::File.run_script(file_path, 60*60*4)
        end
      end
    end
  end
end