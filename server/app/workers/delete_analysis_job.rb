# Delete the files on the server
DeleteAnalysisJob = Struct.new(:analysis_directory) do
  def perform
    FileUtils.rm_rf analysis_directory if Dir.exist? analysis_directory
  end

  def queue_name
    'background'
  end

  def max_attempts
    3
  end
end

