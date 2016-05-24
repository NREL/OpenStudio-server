namespace :run do
  desc 'test pulling in os data'
  task os_data: :environment do
    dp = DataPoint.first
    puts dp.id
    dp.save_results_from_openstudio_json
  end

  desc 'test Rserve connection'
  task test_rserve: :environment do
    r = AnalysisLibrary::Core.initialize_rserve('rserve')
    # r = AnalysisLibrary::Core.initialize_rserve

    puts r
    puts r.converse('2*1000000000')
  end
end
