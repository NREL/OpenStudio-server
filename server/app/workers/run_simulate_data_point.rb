# Command line based interface to execute the Workflow manager.

# ruby worker_init_final.rb -h localhost:3000 -a 330f3f4a-dbc0-469f-b888-a15a85ddd5b4 -s initialize
# ruby simulate_data_point.rb -h localhost:3000 -a 330f3f4a-dbc0-469f-b888-a15a85ddd5b4 -u 1364e270-2841-407d-a495-cf127fa7d1b8

class RunSimulateDataPoint
  def perform
    puts "I am performing..."
    sleep 5
    puts "I am done performing..."
  end
end
