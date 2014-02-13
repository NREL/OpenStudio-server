class AdminController < ApplicationController

  def index

  end

  def backup_database
    write_and_send_data
  end

  private

  def write_and_send_data(file_prefix = "mongodump")
    time_stamp = Time.now.to_i
    dump_dir = "/tmp/#{file_prefix}_#{time_stamp}"
    FileUtils.mkdir_p(dump_dir)
    
    #mongodump  -u admin -p '' --port 30017 -d os_dev -o $BACKUP_DUMP
    `mongodump -db os_dev --out #{dump_dir}`

    output_file = "/tmp/#{file_prefix}_#{time_stamp}.tar.gz"
    `tar czf #{output_file} -C #{dump_dir} os_dev`

    if File.exists?(output_file)
      send_data File.open(output_file).read, :filename => File.basename(output_file), :type => 'application/targz; header=present', :disposition => "attachment"
    else
      raise "could not create dump"
    end
  end
end
