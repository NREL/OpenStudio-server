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

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @data_point.output  }
      #format.json { render json: { :data_point => @data_point.output, :metadata =>  @data_point[:os_metadata] } }
    end
  end

  def show_full
    @data_point = DataPoint.find(params[:id])

    respond_to do |format|
      format.json { render json: @data_point }
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
    @data_point.status = "queued"

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
