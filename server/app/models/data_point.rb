class DataPoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :name, type: String
  field :variable_values # This has been hijacked by OS DataPoint. Use set_variable_values
  field :set_variable_values, type: Hash, default: {} # By default this is a hash list with the name being the id of the variable and the value is the value it was set to.

  field :download_status, type: String, default: 'na'
  field :download_information, type: String
  field :openstudio_datapoint_file_name, type: String # make this paperclip?
  field :status, type: String, default: 'na' # enum of queued, started, completed
  field :status_message, type: String, default: '' # results of the simulation
  field :results, type: Hash, default: {}
  field :run_start_time, type: DateTime, default: nil
  field :run_end_time, type: DateTime, default: nil
  field :sdp_log_file, type: Array, default: []

  # Run location information
  field :ip_address, type: String
  field :internal_ip_address, type: String

  # Relationships
  belongs_to :analysis, index: true

  # Indexes
  index({ uuid: 1 }, unique: true)
  index({ id: 1 }, unique: true)
  index(name: 1)
  index(status: 1)
  index(analysis_id: 1, created_at: 1)
  index(created_at: 1)
  index(uuid: 1, status: 1, download_status: 1)
  index(analysis_id: 1, status: 1, download_status: 1, ip_address: 1)
  index(run_start_time: -1, name: 1)
  index(run_end_time: -1, name: 1)
  index(analysis_id: 1, iteration: 1, sample: 1)
  index(analysis_id: 1, status: 1, status_message: 1, created_at: 1)

  # Callbacks
  after_create :verify_uuid

  # Parse the OpenStudio PAT JSON and save the results into a name:value hash instead of the
  # open structure define in the JSON. This is used for the measure group JSONs only. Deprecate as
  # soon as measure groups are handled correctly.
  def save_results_from_openstudio_json
    # Do not do this because output no longer exists
    # if output && output['data_point'] && output['data_point']['output_attributes']
    #   self.results = {}
    #   output['data_point']['output_attributes'].each do |output_hash|
    #     logger.info(output_hash)
    #     unless output_hash['value_type'] == 'AttributeVector'
    #       output_hash.key?('display_name') ? hash_key = output_hash['display_name'].parameterize.underscore :
    #           hash_key = output_hash['name'].parameterize.underscore
    #       # logger.info("hash name will be: #{hash_key} with value: #{output_hash['value']}")
    #       self['results'][hash_key.to_sym] = output_hash['value']
    #     end
    #   end
    #   self.save!
    # end
  end

  # Perform the final actions on the Data Point.
  def finalize_data_point
    Rails.logger.info 'Post-processing the JSON data that was pushed into the database by the worker'
    save_results_from_openstudio_json
  end

  protected

  def verify_uuid
    self.uuid = id if uuid.nil?
    self.save!
  end
end
