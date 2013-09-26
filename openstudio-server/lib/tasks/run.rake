namespace :run do
  desc 'run and example with R'
  task :example => :environment do
    project = Project.first
    a = project.analyses.first

    a.start_r_and_run_sample
  end

  desc 'test pulling in os data'
  task :os_data => :environment do
    dp = DataPoint.first
    puts dp.id
    dp.save_results_from_openstudio_json


  end
end
