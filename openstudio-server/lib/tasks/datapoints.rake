namespace :datapoints do
  desc 'run and example with R'
  task :download => :environment do
    # Simple task to go through all the datapoints and download the results if they are complete
    Analysis.all.each do |analysis|
      puts "checking datapoints on #{analysis.id}"
      analysis.download_data_from_workers
    end
  end
end
