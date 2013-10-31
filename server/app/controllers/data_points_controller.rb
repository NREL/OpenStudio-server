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

    @html = @data_point.eplus_html
    
    respond_to do |format|
      format.html do
        exclude_fields = [:_id,:output,:password,:eplus_html,:values]
        @table_data = @data_point.as_json(:except => exclude_fields)
        logger.info("Cleaning up the log files")
        if @table_data["sdp_log_file"]
          @table_data["sdp_log_file"] = @table_data["sdp_log_file"].join("</br>").html_safe
        end

        if @data_point.variable_values
          @variable_values = @data_point.variable_values
        end

        # gsub for some styling
        if !@html.nil?
          @html.force_encoding("ISO-8859-1").encode("utf-8", replace: nil).gsub!(/<head>|<body>/, "").gsub!(/<html>|<\/html>/, "").gsub!(/<\/head>|<\/body>/, "")
          #@html.gsub!(/<table .*>/, '<div class="span8"><table id="datapointtable" class="tablesorter table table-striped">')
          #@html.gsub!(/<\/table>/, '</div></table>')
          #@html = @data_point.eplus_html
          #@html =  Zlib::Inflate.inflate(.to_s)
        end
      end
      format.json { render json: @data_point.output }
      #format.json { render json: { :data_point => @data_point.output, :metadata =>  @data_point[:os_metadata] } }
    end
  end

  def show_full
    @data_point = DataPoint.find(params[:id])

    respond_to do |format|
      format.json { render json: @data_point.to_json(:except => [:eplus_html]) }
      #format.json { render json: { :data_point => @data_point.output, :metadata =>  @data_point[:os_metadata] } }
    end
  end

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

    # save off the metadata as a child of the analysis right now... eventually move analysis
    # underneath metadata
    params[:data_point].merge!(:os_metadata => params[:metadata])

    @data_point = DataPoint.new(params[:data_point])

    respond_to do |format|
      if @data_point.save!
        format.html { redirect_to @data_point, notice: 'Data point was successfully created.' }
        format.json { render json: @data_point, status: :created, location: @data_point }
      else
        format.html { render action: "new" }
        format.json { render json: @data_point.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST batch_upload.json
  def batch_upload
    analysis_id = params[:analysis_id]
    logger.info("parsing in a batched file upload")

    uploaded_dps = 0
    saved_dps = 0
    error = false
    error_message = ""
    if params[:data_points]
      uploaded_dps = params[:data_points].count
      logger.info "received #{uploaded_dps} points"
      params[:data_points].each do |dp|
        # read in each datapoint
        dp[:data_point].merge!(:os_metadata => dp[:metadata])
        dp[:data_point][:analysis_id] = analysis_id # need to add in the analysis id to each datapoint
        dp.delete(:metadata) if dp.has_key?(:metadata)
        @data_point = DataPoint.new(dp[:data_point])
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
        format.html { render action: "edit" }
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
    send_data data_point_zip_data, :filename => File.basename(@data_point.openstudio_datapoint_file_name), :type => 'application/zip; header=present', :disposition => "attachment"
  end
end
