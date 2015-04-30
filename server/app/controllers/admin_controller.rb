class AdminController < ApplicationController
  def index
  end

  def backup_database
    logger.info params
    write_and_send_data
  end

  def restore_database
    uploaded_file = params[:file]
    if uploaded_file
      reload_database(uploaded_file)
      redirect_to admin_index_path, notice: "Dropped and Reloaded Database with #{uploaded_file.original_filename}"
    else
      redirect_to admin_index_path, notice: 'No file selected'
    end
  end

  def clear_database
    success_1 = false
    success_2 = false

    logger.info "Working directory is #{Dir.pwd} and I am #{`whoami`}"

    `mongo os_dev --eval "db.dropDatabase();"`
    if $?.exitstatus == 0
      success_1 = true
    end

    # call_rake 'routes' #'db:mongoid:create_indexes'
    # if $?.exitstatus == 0
    #   success_2 = true
    # end

    if success_1 # && success_2
      redirect_to admin_index_path, notice: 'Database deleted successfully.'
    else
      logger.info "Error deleting mongo database: #{success_1}, #{success_2}"
      redirect_to admin_index_path, notice: 'Error deleting database.'
    end
  end

  private

  #  http://railscasts.com/episodes/127-rake-in-background
  def call_rake(task, options = {})
    options[:rails_env] ||= Rails.env
    args = options.map { |n, v| "#{n.to_s.upcase}='#{v}'" }
    system "rake #{task} #{args.join(' ')} --trace 2>&1 >> #{Rails.root}/log/rake.log"
  end

  def reload_database(database_file)
    success = false

    extract_dir = "/tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p(extract_dir)

    resp = `tar xvzf #{database_file.tempfile.path} -C #{extract_dir}`
    if $?.exitstatus == 0
      logger.info 'Successfully extracted uploaded database dump'

      `mongo os_dev --eval "db.dropDatabase();"`
      if $?.exitstatus == 0
        `mongorestore -d os_dev #{extract_dir}/os_dev`
        if $?.exitstatus == 0
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

    resp = `mongodump --db os_dev --out #{dump_dir}`

    if $?.exitstatus == 0
      output_file = "/tmp/#{file_prefix}_#{time_stamp}.tar.gz"
      resp_2 = `tar czf #{output_file} -C #{dump_dir} os_dev`
      if $?.exitstatus == 0
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
