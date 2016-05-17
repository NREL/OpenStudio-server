namespace :run do
  desc 'test pulling in os data'
  task os_data: :environment do
    dp = DataPoint.first
    puts dp.id
    dp.save_results_from_openstudio_json
  end

  desc 'test Rserve connection'
  task :test_rserve do
    require 'rserve/simpler'

    # Figure out how to default all of the calls to Rserve:Simpler

    # options = { hostname: '192.168.99.100', port_number: 6311 }
    options = { hostname: 'rserve', port_number: 6311 }
    r = Rserve::Simpler.new(options)

    puts r
    puts r.converse('2*1000000000')
  end
end
