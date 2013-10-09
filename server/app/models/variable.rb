class Variable
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :version_uuid, :type => String # pointless at this time
  field :name, :type => String
  field :display_name, :type => String
  field :minimum # don't define this--it can be anything
  field :maximum # don't define this--it can be anything
  field :mean # don't define this--it can be anything
  field :distribution, :type => String
  field :data_type, :type => String # not sure this is needed because mongo is typed
  field :variable_index, :type => Integer # for measure groups
  field :argument_index, :type => Integer

  # Relationships
  belongs_to :analysis
  belongs_to :measure

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


  # Create a new variable based on the OS Variable Metadata
  def self.create_from_os_json(analysis_id, os_json)
    var = Variable.where({analysis_id: analysis_id, uuid: os_json['uuid']}).first
    if var
      Rails.logger.warn("Variable already exists for #{var.name} : #{var.uuid}")
    else
      var = Variable.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})
    end

    exclude_fields = ['uuid','type']
    os_json.each do |k,v|
      var[k] = v unless exclude_fields.include? k
    end

    # deal with type or any other "excluded" variables from the hash

    var.save!

    var
  end

  # This method is really not needed once we merge the concept of a argument
  # and a variable
  def self.create_by_os_argument_json(analysis_id, os_json)
    var = Variable.where({analysis_id: analysis_id, uuid: os_json['uuid']}).first
    if var
      Rails.logger.warn("Variable already exists for #{var.name} : #{var.uuid}")
    else
      var = Variable.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})
    end

    exclude_fields = ['uuid','type']
    os_json.each do |k,v|
      var[k] = v unless exclude_fields.include? k
    end

    var.save!

    var
  end

  protected

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end
end
