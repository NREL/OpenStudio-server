# Abstract class to communicate the state of the analysis. Currently only the
# Mongo communicator has been implemented/tested
class AnalysisChauffeur
  attr_accessor :communicate_object

  def initialize(uuid_or_path, library_path="/mnt/openstudio", communicate_method="communicate_mongo")
    if communicate_method == "communicate_mongo"
      require "#{library_path}/#{communicate_method}.rb"

      require 'mongoid'
      require 'mongoid_paperclip'
      require 'delayed_job_mongoid'
      Dir["#{library_path}/rails-models/*.rb"].each { |f| require f }
      Mongoid.load!("#{library_path}/rails-models/mongoid.yml", :development)

      # right now this is always a path, but need a regex or flag to decipher right
      @communicate_object = get_datapoint(uuid_or_path)
    else
      raise "No Communicate Module found for #{communicate_method} in #{__FILE__}"
    end

    @communicate_module = communicate_method.camelcase(:upper).constantize
    @time = Time.now # make this a module method
  end

  def communicate_started
    #communicate_method.camelize.constantize
    @communicate_module.communicate_started(@communicate_object)
  end

  def communicate_datapoint(os_data_point)
    @communicate_module.communicate_datapoint(@communicate_object, os_data_point)
  end

  def log_message(log_message, delta=false)
    @communicate_module.communicate_log_message(@communicate_object, log_message, delta, @time)
    @time = Time.now
  end

  def get_problem_json
    @communicate_module.get_problem_json(@communicate_object)
  end

  def communicate_results(os_data_point, os_directory)
    @communicate_module.communicate_results(@communicate_object, os_data_point, os_directory)
  end

  def communicate_complete
    @communicate_module.communicate_complete(@communicate_object)
  end

  def communicate_failure
    @communicate_module.communicate_failure(@communicate_object)
  end

  def reload
    @communicate_module.reload(@communicate_object)
  end

  private

  def get_datapoint(id)
    # TODO : make this not a find_or_create, but rather a find or crash (not sure about optimization though... ugh.)
    @communicate_object = DataPoint.find_or_create_by(uuid: id)
  end

end