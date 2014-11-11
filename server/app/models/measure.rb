class Measure
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, type: String
  field :_id, type: String, default: -> { uuid || SecureRandom.uuid }
  field :version_uuid, type: String # pointless at this time
  field :name, type: String
  field :display_name, type: String
  field :description, type: String
  field :arguments # This is really the variable? right?
  field :measure_type, type: String
  field :values, type: Array, default: []
  field :index, type: Integer # how do we set the index, i guess an oncreate call back :~

  # Relationships
  belongs_to :analysis
  has_many :variables

  # Indexes
  index({ uuid: 1 }, unique: true)
  index({ id: 1 }, unique: true)
  index(name: 1)
  index(analysis_id: 1)
  index(analysis_id: 1, uuid: 1)
  index({analysis_id: 1, name: 1}, unique: true)

  # Callbacks
  after_create :verify_uuid

  # Parse Analysis JSON to pull out the measures and variables
  # Format of JSON is typically
  # {
  #     "measure_definition_class_name": "AddOverhangsByProjectionFactor",
  #     "measure_definition_directory": "./measures/AddOverhangsByProjectionFactor",
  #     "measure_definition_display_name": "AddOverhangsByProjectionFactor",
  #     "measure_definition_uuid": "a15669c4-2d37-4177-913c-f62bd8159c7a",
  #     "measure_definition_version_uuid": "1de14091-ccb5-4dfd-8476-a3e4873af54b",
  #     "measure_type": "RubyMeasure",
  #     "arguments": [
  #       {
  #         "display_name": "Cardinal Direction",
  #         "display_name_short": "Cardinal Direction",
  #         "name": "facade",
  #         "value": "East",
  #         "value_type": "choice"
  #       }
  #     ]
  #     "display_name": "Overhangs PF East",
  #     "name": "overhangs_pf_east",
  #     "variables": [
  #       {
  #         "argument": {
  #           "display_name": "East Projection Factor",
  #           "display_name_short": "East PF",
  #           "name": "projection_factor",
  #           "value_type": "double"
  #         },
  #         "display_name": "East Projection Factor",
  #         "display_name_short": "East PF",
  #         "maximum": 1.0,
  #         "minimum": 0.0,
  #         "relation_to_output": "",
  #         "static_value": 0.0,
  #         "uncertainty_description": {}
  #       }
  #     ],
  #     "workflow_index": 8,
  #     "workflow_step_type": "Measure",
  #     "uuid": "657880ff-8a11-4e8a-ac71-935f26f89e48",
  #     "version_uuid": "8fddf44c-3335-4908-a824-042eec210984"
  #   }
  def self.create_from_os_json(analysis_id, os_json, pat_json)
    # The UUID is a misnomer because in measure groups the exact same measure is copied over multiple times. The
    # Unique ID is the anlaysis id and the name combined.
    # **Measure names must be unique and enforced by whatever software is writing the JSON**
    measure = Measure.where(analysis_id: analysis_id, name: os_json['name']).first
    if measure
      # since the index is unique, this should fail before this point
      fail "Measure already exists for analysis #{analysis_id} of #{measure.name}"
    else
      measure = Measure.find_or_create_by(analysis_id: analysis_id, name: os_json['name'])
      Rails.logger.info("Creating new measure for analysis #{analysis_id} with name '#{measure.name}'")
    end

    Rails.logger.info("Adding/updating measure #{measure.name} for analysis #{analysis_id}")
    i_measure = 0
    os_json.each do |k, v|
      exclude_fields = %w(arguments variables)

      # check for null measures
      # Rails.logger.info("trying to add #{k} : #{v}")
      measure[k] = v unless exclude_fields.include? k

      # Rails.logger.info(k)
      if k['measure_type'] && v == 'NullMeasure'
        # this is a null measure--but has no name
        Rails.logger.info('Null measure found')
        measure.name = 'NullMeasure'
      end
    end

    # Pull out the arugments that are in the measure
    if os_json['arguments']
      # Rails.logger.info("#{k.inspect} #{v.inspect}")
      os_json['arguments'].each do |arg|
        # Create a variable definition (i.e. a variable) for each argument regardless
        # whether or not it is used
        new_var = Variable.create_and_assign_to_measure(analysis_id, measure, arg)
        # Rails.logger.info("New variable is #{new_var}")
        measure.variables << new_var unless measure.variables.include?(new_var)

        if pat_json
          # The measure.values field is just a list of all the set values for the
          # measure groups which really isn't needed for LHS nor optimization.
          if arg['value'] && arg['argument_index']
            # let the system know that the variable was selected for "manipulation"
            # Rails.logger.info("letting the system know that it can use this variable #{new_var.inspect}")
            # new_var.perturbable = true
            # new_var.save!

            # Rails.logger.info("adding #{arg['value']}")
            measure.values << [arg['argument_index'], arg['value']]
          end
        end
      end
    end

    if os_json['variables']
      os_json['variables'].each do |json_var|
        Rails.logger.info "JSON had a variable named '#{json_var['display_name']}'"
        new_var = Variable.create_and_assign_to_measure(analysis_id, measure, json_var)

        if new_var.save!
          measure.variables << new_var unless measure.variables.include?(new_var)
        end
      end
    end

    # deal with type or any other "excluded" variables from the hash
    measure.save!

    measure
  end

  protected

  def verify_uuid
    self.uuid = id if uuid.nil?
    self.save!
  end
end
