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

  def self.create_by_os_json(analysis_id, os_json)
    var = Variable.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})

    os_json.each do |k,v|
      next if ['uuid','type'].include? k
      var[k] = v
    end

    # deal with type or any other "excluded" variables from the hash

    var.save!

    var
  end

  protected

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end
end
