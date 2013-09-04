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
      format.json { render json: @data_point  }
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

    @data_point = DataPoint.new(params[:data_point])

    respond_to do |format|
      if @data_point.save
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
    @data_point.destroy

    respond_to do |format|
      format.html { redirect_to data_points_url }
      format.json { head :no_content }
    end
  end
end
