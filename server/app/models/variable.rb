class Variable
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :version_uuid, :type => String # pointless at this time
  field :name, :type => String
  field :display_name, :type => String
  field :minimum # don't define this--it can be anything  -- and remove this eventually as os uses lower bounds
  field :maximum # don't define this--it can be anything
  field :mean # don't define this--it can be anything
  field :uncertainty_type, :type => String
  field :data_type, :type => String # not sure this is needed because mongo is typed
  field :variable_index, :type => Integer # for measure groups
  field :argument_index, :type => Integer
  field :perturbable, :type => Boolean, default: false # if eneabled, then it will be perturbed
  scope :enabled, where(perturbable: true)

  # Relationships
  belongs_to :analysis
  belongs_to :measure
  has_many :preflight_images

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({analysis_id: 1})
  index({analysis_id: 1, uuid: 1})
  index({analysis_id: 1, perturbable: 1})

  # Validations
  # validates_format_of :uuid, :with => /[^0-]+/
  # validates_attachment :seed_zip, content_type: { content_type: "application/zip" }

  # Callbacks
  after_create :verify_uuid
  before_destroy :remove_dependencies


  # Create a new variable based on the OS Variable Metadata
  def self.create_from_os_json(analysis_id, os_json)
    var = Variable.where({analysis_id: analysis_id, uuid: os_json['uuid']}).first
    if var
      Rails.logger.warn("Variable already exists for #{var.name} : #{var.uuid}")
    else
      var = Variable.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})
    end

    exclude_fields = ['uuid', 'type']
    os_json.each do |k, v|
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

    exclude_fields = ['uuid', 'type', 'argument', 'uncertainty_description']
    os_json.each do |k, v|
      var[k] = v unless exclude_fields.include? k

      if k == "argument"
        # this is main portion of the variable
        exclude_fields_2 = ['uuid', 'version_uuid']
        v.each do |k2, v2|
          var[k2] = v2 unless exclude_fields_2.include? k2
        end
      end

      if k == "uncertainty_description"
        # need to flatten this
        var['uncertainty_type'] = v['type'] if v['type']
        if v['attributes']
          v['attributes'].each do |attribute|
            # grab the name of the attribute to append the
            # other characteristics
            attribute['name'] ? att_name = attribute['name'] : att_name = nil
            next if !att_name
            attribute.each do |k2, v2|
              exclude_fields_2 = ['uuid', 'version_uuid', 'name']
              var["#{att_name}_#{k2}"] = v2  unless exclude_fields_2.include? k2
            end
          end
        end
      end
    end

    var.save!

    var
  end

  protected

  def verify_uuid
    self.uuid = self.id if self.uuid.nil?
    self.save!
  end

  def remove_dependencies
    self.preflight_images.each do |pfi|
      pfi.destroy
    end
  end
end
