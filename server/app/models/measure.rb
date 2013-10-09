class Measure
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :version_uuid, :type => String # pointless at this time
  field :name, :type => String
  field :display_name, :type => String
  field :description, :type => String
  field :arguments  # This is really the variable? right?
  field :measure_type, :type => String
  field :values, :type => Array, default: []

  # Relationships
  belongs_to :analysis

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({analysis_id: 1})

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  # validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  # Callbacks
  after_create :verify_uuid
  #before_destroy :remove_dependencies

  def self.create_from_os_json(analysis_id, os_json)

    # I really thin the BCL is the unique measure id here, not the uuid... tbd
    measure = Measure.where({analysis_id: analysis_id, uuid: os_json['bcl_measure_uuid']}).first
    if measure
      Rails.logger.warn("Measure already exists for #{measure.name} : #{measure.uuid}")
    else
      measure = Measure.find_or_create_by({analysis_id: analysis_id, uuid: os_json['bcl_measure_uuid']})
    end

    Rails.logger.info("updating measure #{measure.id}")
    os_json.each do |k, v|
      exclude_fields = ["uuid","bcl_measure_uuid","arguments"]

      if k['measure_type'] && k['measure_type'] == "NullMeasure"
        # this is a null measure--but has no name
        measure.name = "NullMeasure"
      end

      # check for null measures
      Rails.logger.info("trying to add #{k} : #{v}")
      measure[k] = v unless exclude_fields.include? k

      # Also pull out the value fields for each for each of these and save into a variable instance "somehow???"
      if v == "arguments"
        # just append this to an array for now...
        # jam this data into the measure for now, but this needs to get pulled out into
        # variables
        measure[k] = v
        measure['arguments'].each do |arg|
          if arg['value']
            logger.info("adding #{arg['value']}")
            measure.values << arg['value']
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
