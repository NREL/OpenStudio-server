namespace :run do
  desc 'test pulling in os data'
  task :os_data => :environment do
    dp = DataPoint.first
    puts dp.id
    dp.save_results_from_openstudio_json
  end
end
