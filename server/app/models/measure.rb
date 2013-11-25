class Measure
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :version_uuid, :type => String # pointless at this time
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String
  field :arguments # This is really the variable? right?
  field :measure_type, :type => String
  field :values, :type => Array, default: []
  field :index, :type => Integer  # how do we set the index, i guess an oncreate call back :~

  # Relationships
  belongs_to :analysis
  has_many :variables

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({analysis_id: 1})
  index({analysis_id: 1, uuid: 1})

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  # validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  # Callbacks
  after_create :verify_uuid

  # parse openstudio's json to get out the variables
  def self.create_from_os_json(analysis_id, os_json, pat_json)

    # The UUID is a misnomer because in measure groups the exact same measure
    # is copied over multiple times.  The BCL UUID is the actual unique ID IMO.
    measure = Measure.where({analysis_id: analysis_id, uuid: os_json['uuid']}).first
    if measure
      Rails.logger.info("Measure already exists for analysis #{analysis_id} of #{measure.name} : #{measure.uuid}")
    else
      measure = Measure.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})
      Rails.logger.info("Creating new measure for analysis #{analysis_id} with uuid '#{measure.uuid}'")
    end

    Rails.logger.info("adding/updating measure #{measure.uuid} for analysis #{analysis_id}")
    i_measure = 0
    os_json.each do |k, v|
      exclude_fields = ["arguments", "variables"]

      # check for null measures
      #Rails.logger.info("trying to add #{k} : #{v}")
      measure[k] = v unless exclude_fields.include? k

      #Rails.logger.info(k)
      if k['measure_type'] && v == "NullMeasure"
        # this is a null measure--but has no name
        Rails.logger.info("Null measure found")
        measure.name = "NullMeasure"
      end

      # Also pull out the value fields for each for each of these and save into a variable instance "somehow???"
      if k == "arguments"
        #Rails.logger.info("checking arguments for values")
        # just append this to an array for now...
        # jam this data into the measure for now, but this needs to get pulled out into
        #Rails.logger.info("#{k.inspect} #{v.inspect}")
        if v
          v.each do |arg|
            #Rails.logger.info(arg.inspect)

            # Create a variable definition (i.e. a variable) for each argument regardless
            # whether or not it is used
            new_var = Variable.create_by_os_argument_json(analysis_id, arg)
            #Rails.logger.info("New variable is #{new_var}")
            measure.variables << new_var unless measure.variables.include?(new_var)

            if pat_json
              # The measure.values field is just a list of all the set values for the
              # measure groups which really isn't needed for LHS nor optimization.
              if arg['value'] && arg['argument_index']
                # let the system know that the variable was selected for "manipulation"
                #Rails.logger.info("letting the system know that it can use this variable #{new_var.inspect}")
                #new_var.perturbable = true
                #new_var.save!

                #Rails.logger.info("adding #{arg['value']}")
                measure.values << [arg['argument_index'], arg['value']]
              end
            end
          end
        end
      end

      if k == "variables"
        v.each do |json_var|
          Rails.logger.info "JSON had a variable named '#{json_var[:name]}'"
          new_var = Variable.create_by_os_argument_json(analysis_id, json_var)
          
          if new_var.save!
            measure.variables << new_var  unless measure.variables.include?(new_var)
          end
          
        end
      end
    end

    # deal with type or any other "excluded" variables from the hash
    measure.save!

    measure
  end

  protected

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end
end
