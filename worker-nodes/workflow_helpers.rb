module WorkflowHelpers
  def self.prepare_run_directory(file_src_dir, dirname, options = {})
    puts "preparing run diretory #{dirname} with #{options}"
    FileUtils.rm_rf(dirname) if File.exist?(dirname)
    FileUtils.mkdir_p(dirname)

    FileUtils.copy("#{file_src_dir}/#{options[:run_data_point_filename]}", "#{dirname}/#{options[:run_data_point_filename]}")
    FileUtils.copy("#{file_src_dir}/run_energyplus.rb", "#{dirname}/run_energyplus.rb")
    FileUtils.copy("#{file_src_dir}/post_process.rb", "#{dirname}/post_process.rb") # todo: remove
    FileUtils.copy("#{file_src_dir}/post_process_monthly.rb", "#{dirname}/post_process_monthly.rb") # todo: remove
    FileUtils.copy("#{file_src_dir}/monthly_report.idf", "#{dirname}/monthly_report.idf")
    FileUtils.cp_r("#{file_src_dir}/packaged_measures", "#{dirname}/packaged_measures")
  end
end
