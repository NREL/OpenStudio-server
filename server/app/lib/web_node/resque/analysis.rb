# Functions required by Analysis class when running on Web in environment that leverages Resque
module WebNode
  module Resque
    module Analysis
      # path to analysis in osdata volume
      def shared_directory_path
        "#{APP_CONFIG['server_asset_path']}/analysis/#{id}"
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
        logger.info "Extracting seed zip to #{shared_directory_path}"
        begin
          Timeout.timeout(180) do
            extract_count += 1
            OpenStudio::Workflow.extract_archive(seed_zip.path, shared_directory_path)
          end
        rescue => e
          retry if extract_count < extract_max_count
          raise "Extraction of the seed.zip file failed #{extract_max_count} times with error #{e.message}"
        end
      end

      # Unpack analysis.zip into the osdata volume for use by background and web
      # specific usecase is to run analysis initialization and finalization scripts.
      # currently only used with Resque, as it's called by ResqueJobs::InitializeAnalysis job
      # runs on web node
      def run_finalization
        #   unpack seed zip file into osdata
        #   run finalize.sh if present
        # Extract the zip
        extract_count = 0
        extract_max_count = 3
        logger.info "Extracting seed zip to #{shared_directory_path}"
        begin
          Timeout.timeout(180) do
            extract_count += 1
            OpenStudio::Workflow.extract_archive(seed_zip.path, shared_directory_path)
          end
        rescue => e
          retry if extract_count < extract_max_count
          raise "Extraction of the seed.zip file failed #{extract_max_count} times with error #{e.message}"
        end
      end
    end
  end
end