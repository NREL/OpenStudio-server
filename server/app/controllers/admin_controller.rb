class AdminController < ApplicationController
  def index
  end

  def backup_database
    write_and_send_data
  end

  def restore_database
    uploaded_file = params[:file]

    reload_database(uploaded_file)

    redirect_to admin_index_path, notice: "Dropped and Reloaded Database with #{uploaded_file.original_filename}"
  end

  private

  def reload_database(database_file)
    success = false

    extract_dir = "/tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p(extract_dir)

    resp = `tar xvzf #{database_file.tempfile.path} -C #{extract_dir}`
    if $CHILD_STATUS.exitstatus == 0
      logger.info 'Successfully extracted uploaded database dump'

      `mongo os_dev --eval "db.dropDatabase();"`
      if $CHILD_STATUS.exitstatus == 0
        `mongorestore -d os_dev #{extract_dir}/os_dev`
        if $CHILD_STATUS.exitstatus == 0
          logger.info 'Restored mongo database'
          success = true
        else
          logger.info 'Error trying to reload mongo database'
        end
      end
    end

    success
  end

  def write_and_send_data(file_prefix = 'mongodump')
    success = false

    time_stamp = Time.now.to_i
    dump_dir = "/tmp/#{file_prefix}_#{time_stamp}"
    FileUtils.mkdir_p(dump_dir)

    # mongodump  -u admin -p '' --port 30017 -d os_dev -o $BACKUP_DUMP
    resp = `mongodump -db os_dev --out #{dump_dir}`

    if $CHILD_STATUS.exitstatus == 0
      output_file = "/tmp/#{file_prefix}_#{time_stamp}.tar.gz"
      resp_2 = `tar czf #{output_file} -C #{dump_dir} os_dev`
      if $CHILD_STATUS.exitstatus == 0
        success = true
      end
    end

    if File.exist?(output_file)
      send_data File.open(output_file).read, filename: File.basename(output_file), type: 'application/targz; header=present', disposition: 'attachment'
      success = true
    else
      fail 'could not create dump'
    end

    success
  end
end
