class DataPointsController < ApplicationController
  # GET /data_points
  # GET /data_points.json
  def index
    @data_points = DataPoint.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @data_points }
    end
  end

  # GET /data_points/1
  # GET /data_points/1.json
  def show
    @data_point = DataPoint.find(params[:id])
    @htmls = []
    respond_to do |format|
      if @data_point
        format.html do
          exclude_fields = [:_id, :output, :password, :values]
          @table_data = @data_point.as_json(except: exclude_fields)

          logger.info('Cleaning up the log files')
          if @table_data['sdp_log_file']
            @table_data['sdp_log_file'] = @table_data['sdp_log_file'].join('</br>').html_safe
          end

          @data_point.set_variable_values ? @set_variable_values = @data_point.set_variable_values : @set_variable_values = []

          if @data_point.openstudio_datapoint_file_name
            local_analysis_dir = "#{File.dirname(@data_point.openstudio_datapoint_file_name.to_s)}/#{File.basename(@data_point.openstudio_datapoint_file_name.to_s, '.*')}"
            logger.debug "Local analysis dir is #{local_analysis_dir}"
            Dir["#{local_analysis_dir}/reports/*.html"].each do |h|
              new_h = {}
              new_h[:filename] = h
              new_h[:name] = File.basename(h, '.*')
              new_h[:display_name] = new_h[:name].titleize
              @htmls << new_h
            end
          end
        end

        format.json do
          @data_point = @data_point.as_json
          @data_point['set_variable_values_names'] = {}
          @data_point['set_variable_values_display_names'] = {}
          @data_point['set_variable_values'].each do |k, v|
            var = Variable.find(k)
            if var
              new_key = var ? var.name : k
              new_display_key = var ? var.display_name : k
              @data_point['set_variable_values_names'][new_key] = v
              @data_point['set_variable_values_display_names'][new_display_key] = v
            end
          end

          render json: @data_point
        end
      else
        format.html { redirect_to projects_path, notice: 'Could not find data point' }
        format.json { render json: { error: 'No Data Point' }, status: :unprocessable_entity }
      end
    end
  end
  alias_method :show_full, :show

  # GET /data_points/new
  # GET /data_points/new.json
  def new
    @data_point = DataPoint.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @data_point }
    end
  end

  # GET /data_points/1/edit
  def edit
    @data_point = DataPoint.find(params[:id])
  end

  # POST /data_points
  # POST /data_points.json
  def create
    analysis_id = params[:analysis_id]
    params[:data_point][:analysis_id] = analysis_id

    @data_point = DataPoint.new(params[:data_point])

    respond_to do |format|
      if @data_point.save!
        format.html { redirect_to @data_point, notice: 'Data point was successfully created.' }
        format.json { render json: @data_point, status: :created, location: @data_point }
      else
        format.html { render action: 'new' }
        format.json { render json: @data_point.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST batch_upload.json
  def batch_upload
    analysis_id = params[:analysis_id]
    logger.info('parsing in a batched file upload')

    uploaded_dps = 0
    saved_dps = 0
    error = false
    error_message = ''
    if params[:data_points]
      uploaded_dps = params[:data_points].count
      logger.info "received #{uploaded_dps} points"
      params[:data_points].each do |dp|
        # This is the old format that can be deprecated when OpenStudio V1.1.3 is released
        dp[:analysis_id] = analysis_id # need to add in the analysis id to each datapoint

        @data_point = DataPoint.new(dp)
        if @data_point.save!
          saved_dps += 1
        else
          error = true
          error_message += "could not proccess #{@data_point.errors}"
        end
      end
    end

    respond_to do |format|
      logger.info("error flag was set to #{error}")
      if !error
        format.json { render json: "Created #{saved_dps} datapoints from #{uploaded_dps} uploaded.", status: :created, location: @data_point }
      else
        format.json { render json: error_message, status: :unprocessable_entity }
      end
    end
  end

  # PUT /data_points/1
  # PUT /data_points/1.json
  def update
    @data_point = DataPoint.find(params[:id])

    respond_to do |format|
      if @data_point.update_attributes(params[:data_point])
        format.html { redirect_to @data_point, notice: 'Data point was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @data_point.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /data_points/1
  # DELETE /data_points/1.json
  def destroy
    @data_point = DataPoint.find(params[:id])
    analysis_id = @data_point.analysis
    @data_point.destroy

    respond_to do |format|
      format.html { redirect_to analysis_path(analysis_id) }
      format.json { head :no_content }
    end
  end

  def download
    @data_point = DataPoint.find(params[:id])

    data_point_zip_data = File.read(@data_point.openstudio_datapoint_file_name)
    send_data data_point_zip_data, filename: File.basename(@data_point.openstudio_datapoint_file_name), type: 'application/zip; header=present', disposition: 'attachment'
  end

  def download_reports
    @data_point = DataPoint.find(params[:id])

    remote_filename_reports = @data_point.openstudio_datapoint_file_name.gsub('.zip', '_reports.zip')
    data_point_zip_data = File.read(remote_filename_reports)
    send_data data_point_zip_data, filename: File.basename(remote_filename_reports), type: 'application/zip; header=present', disposition: 'attachment'
  end

  def view_report
    html_file = params[:html_file]

    if File.exist? html_file
      @html = File.read html_file
    else
      @html = 'Could not find file'
    end
  end

  def dencity
    @data_point = DataPoint.find(params[:id])

    dencity = nil
    if @data_point
      # reformat the data slightly to get a concise view of the data
      dencity = {}

      # instructions for building the inputs
      measure_instances = []
      if @data_point.analysis['problem']
        if @data_point.analysis['problem']['workflow']
          @data_point.analysis['problem']['workflow'].each_with_index do |wf, _index|
            m_instance = {}
            m_instance['uri'] = 'https://bcl.nrel.gov or file:///local'
            m_instance['id'] = wf['measure_definition_uuid']
            m_instance['version_id'] = wf['measure_definition_version_uuid']

            if wf['arguments']
              m_instance['arguments'] = {}
              if wf['variables']
                wf['variables'].each do |var|
                  m_instance['arguments'][var['argument']['name']] = @data_point.set_variable_values[var['uuid']]
                end
              end

              wf['arguments'].each do |arg|
                m_instance['arguments'][arg['name']] = arg['value']
              end
            end

            measure_instances << m_instance
          end
        end
      end

      dencity[:measure_instances] = measure_instances

      # Don't use this old method.  Instead get the dencity reporting variables from the metadata_id flag
      # dencity[:structure] = @data_point[:results]['dencity_reports']

      # Grab all the variables that have defined a measure ID and pull out the results
      vars = @data_point.analysis.variables.where(:metadata_id.exists => true, :metadata_id.ne => '')
          .order_by(:name.asc).as_json(only: [:name, :metadata_id])

      dencity[:structure] = {}
      vars.each do |v|
        a, b = v['name'].split('.')
        logger.info "#{v[:metadata_id]} had #{a} and #{b}"

        if dencity[:structure][v['metadata_id']].present?
          logger.error "DEnCity variable '#{v['metadata_id']} is already defined in output as #{a}:#{b}"
        end

        if @data_point[:results][a].present? && @data_point[:results][a][b].present?
          dencity[:structure][v['metadata_id']] = @data_point[:results][a][b]
        else
          logger.warn 'could not find result'
          dencity[:structure][v['metadata_id']] = nil
        end
      end
    end

    respond_to do |format|
      if dencity
        format.json { render json: dencity.to_json }
      else
        format.json { render json: { error: 'Could not format data point into DEnCity view' }, status: :unprocessable_entity }
      end
    end
  end
end
