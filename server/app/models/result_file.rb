# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class ResultFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  field :display_name, type: String
  field :type, type: String # Results, Rdata, Data Point, OpenStudio Model

  # TODO: allow for various paths for saving these files
  has_mongoid_attached_file :attachment,
                            url: '/assets/data_points/:id/files/:style/:basename.:extension',
                            path: "#{APP_CONFIG['server_asset_path']}/assets/data_points/:id/files/:style/:basename.:extension"

  # Relationships
  embedded_in :data_point

  # Validations
  do_not_validate_attachment_file_type :attachment
end
