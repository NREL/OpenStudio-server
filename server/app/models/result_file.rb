class ResultFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  field :display_name, type: String
  field :type, type: String # Results, Rdata, Reporting (all zips)

  # TODO: allow for various paths for saving these files
  has_mongoid_attached_file :attachment,
                            url: '/assets/data_points/:id/files/:style/:basename.:extension',
                            path: ':rails_root/public/assets/data_points/:id/files/:style/:basename.:extension'

  # Relationships
  embedded_in :data_point

  # Validations
  validates_attachment_content_type :attachment, content_type: %w(application/zip text/html text/json), message: 'Only html, zip, and json files are allowed to be uploaded'
end
