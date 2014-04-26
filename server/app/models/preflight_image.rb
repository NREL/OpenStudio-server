class PreflightImage
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  field :image_type, type: String

  has_mongoid_attached_file :image,
                            url: '/assets/variables/:id/:style/:basename.:extension',
                            path: ':rails_root/public/assets/variables/:id/:style/:basename.:extension',
                            styles: {
                              original: ['1920x1680>', :png],
                              thumb: ['150x150#', :png],
                              large: ['500x500>', :png],
                              small: ['360x360>', :png]
                            }

  belongs_to :variable

  validates_attachment_content_type :image, content_type: %w(image/png)

  def self.add_from_disk(var_id, image_type, filename)
    pfi = PreflightImage.new(variable_id: var_id, image_type: image_type)

    logger.info("adding preflight file #{filename}")
    if File.exist?(filename)
      file = File.open(filename, 'rb')
      pfi.image = file
      file.close
    end
    pfi.save!

    pfi
  end
end
