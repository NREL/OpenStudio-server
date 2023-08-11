# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class PreflightImage
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  field :image_type, type: String

  has_mongoid_attached_file :image,
                            url: '/assets/variables/:id/:style/:basename.:extension',
                            path: "#{APP_CONFIG['server_asset_path']}/assets/variables/:id/:style/:basename.:extension",
                            styles: {
                              original: ['1920x1680>', :png],
                              thumb: ['150x150#', :png],
                              large: ['500x500>', :png],
                              small: ['360x360>', :png]
                            }

  belongs_to :variable

  validates_attachment_content_type :image, content_type: ['image/png']

  def self.add_from_disk(var_id, image_type, filename)
    pfi = PreflightImage.new(variable_id: var_id, image_type: image_type)

    if File.exist?(filename)
      logger.info("adding preflight file #{filename}")
      file = File.open(filename, 'rb')
      pfi.image = file
      file.close
      File.chmod(0o666, filename)
    end
    pfi.save!

    pfi
  end
end
