class Variable
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, :type => String
  field :_id, :type => String, default: -> { uuid || UUID.generate }
  field :r_index, :type => Integer
  field :version_uuid, :type => String # pointless at this time
  field :name, :type => String
  field :display_name, :type => String
  field :minimum # don't define this--it can be anything  -- and remove this eventually as os uses lower bounds
  field :maximum # don't define this--it can be anything
  field :mean # don't define this--it can be anything
  field :uncertainty_type, :type => String
  field :discrete_values_and_weights
  field :data_type, :type => String # not sure this is needed because mongo is typed
  field :variable_index, :type => Integer # for measure groups
  field :argument_index, :type => Integer
  field :perturbable, :type => Boolean, default: false # if enabled, then it will be perturbed
  field :pivot, :type => Boolean, default: false
  field :pivot_samples # don't type for now
  field :static, :type => Boolean, default: false
  field :relation_to_output => String, default: "standard" # or can be inverse
  field :static_value # don't type this because it can take on anything (other than hashes and arrays)
  scope :enabled, where(perturbable: true)

  # Relationships
  belongs_to :analysis
  belongs_to :measure
  has_many :preflight_images

  # Indexes
  index({uuid: 1}, unique: true)
  index({id: 1}, unique: true)
  index({name: 1})
  index({r_index: 1})
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
      Rails.logger.info "create new variable for os_json['uuid']"
      var = Variable.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})
      Rails.lgger.info var.inspect
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
      Rails.logger.warn("Variable already exists for '#{var.name}' : '#{var.uuid}'")
    else
      Rails.logger.info("Adding a new variable/argument named: '#{os_json['name']}' with UUID '#{os_json['uuid']}'")
      var = Variable.find_or_create_by({analysis_id: analysis_id, uuid: os_json['uuid']})
    end

    exclude_fields = ['uuid', 'type', 'argument', 'uncertainty_description']
    os_json.each do |k, v|
      var[k] = v unless exclude_fields.include? k

      # Map these temporary terms ??
      var.perturbable = v if k == 'variable'

      if k == "argument"
        # this is main portion of the variable
        exclude_fields_2 = ['uuid', 'version_uuid']
        v.each do |k2, v2|
          var[k2] = v2 unless exclude_fields_2.include? k2
        end
      end

      # if the variable has an uncertainty description, then it needs to be flagged
      # as a perturbable (or pivot) variable
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
              var["#{att_name}_#{k2}"] = v2 unless exclude_fields_2.include? k2
            end
          end
        end
      end
    end

    var.save!

    var
  end

  def self.pivots(analysis_id)
    Variable.where({analysis_id: analysis_id, pivot: true}).order_by(:name.asc)
  end

  # start with a hash and then create the hash_of_arrays
  def self.pivot_array(analysis_id)
    pivot_variables = Variable.pivots(analysis_id)

    pivot_hash = {}
    pivot_variables.each do |var|
      Rails.logger.info "Adding variable '#{var.name}' to pivot list"
      Rails.logger.info "Mapping pivot #{var.name} with #{var.map_discrete_hash_to_array}"
      values, weights = var.map_discrete_hash_to_array # weights are ignored in pivots
      Rails.logger.info "pivot variable values are #{values}"
      pivot_hash[var.uuid] = values
    end

    # if there are multiple pivots, then smash the hash of arrays to form a array of hashes
    pivot_array = Analysis::Core.hash_of_array_to_array_of_hash(pivot_hash)
    Rails.logger.info "pivot array is #{pivot_array}"

    pivot_array
  end

  def self.statics(analysis_id)
    Variable.where({analysis_id: analysis_id, static: true}).order_by(:name.asc)
  end

  def self.static_array(analysis_id, grouped=false, array_around_grouped_value = true)
    # get static variables.  These must be applied after the pivot vars and before the lhs
    static_variables = Variable.statics(analysis_id)
    grouped_hash = {}
    static_array = []
    static_variables.each do |var|
      if var.static_value
        if grouped
          grouped_hash["#{var.measure.id}"] = {} if !grouped_hash.has_key?(var.measure.id)
          if array_around_grouped_value
            grouped_hash["#{var.measure.id}"]["#{var.id}"] = [var.static_value]
          else
            grouped_hash["#{var.measure.id}"]["#{var.id}"] = var.static_value
          end
        else
          static_array << {"#{var.id}" => var.static_value}
        end
      else
        raise "Asking to set a static value but none was passed for #{var.name}"
      end
    end
    Rails.logger.info "static array is #{static_array}"
    Rails.logger.info "grouped static hash is #{grouped_hash}"

    static_array = grouped_hash if grouped
    static_array
  end

  def self.variables(analysis_id)
    Variable.where({analysis_id: analysis_id, perturbable: true}).order_by(:name.asc)
  end
  
  def map_discrete_hash_to_array
    Rails.logger.info "Discrete values and weights are #{self.discrete_values_and_weights}"
    Rails.logger.info "received map discrete values with #{self.discrete_values_and_weights} with size #{self.discrete_values_and_weights.size}"
    ave_weight = (1.0 / self.discrete_values_and_weights.size)
    Rails.logger.info "average weight is #{ave_weight}"
    self.discrete_values_and_weights.each_index do |i|
      if !self.discrete_values_and_weights[i].has_key? 'weight'
        self.discrete_values_and_weights[i]['weight'] = ave_weight
      end
    end
    values = self.discrete_values_and_weights.map { |k| k['value'] }
    weights = self.discrete_values_and_weights.map { |k| k['weight'] }
    logger.info "Set values and weights to  #{values} with size #{weights}"

    [values, weights]
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
