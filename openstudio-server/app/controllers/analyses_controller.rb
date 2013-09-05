class AnalysesController < ApplicationController
  # GET /analyses
  # GET /analyses.json
  def index
    if params[:project_id].nil?
      @analyses = Analysis.all
    else
      @analysis = Project.find(params[:project_id]).analyses
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @analyses }
    end
  end

  # GET /analyses/1
  # GET /analyses/1.json
  def show
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analysis.to_json(:include => :data_points) }
    end
  end

  # GET /analyses/new
  # GET /analyses/new.json
  def new
    @analysis = Analysis.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @analysis }
    end
  end

  # GET /analyses/1/edit
  def edit
    @analysis = Analysis.find(params[:id])
  end

  # POST /analyses
  # POST /analyses.json
  def create
    project_id = params[:project_id]
    params[:analysis][:project_id] = project_id
    @analysis = Analysis.new(params[:analysis])
    
    respond_to do |format|
      if @analysis.save
        format.html { redirect_to @analysis, notice: 'Analysis was successfully created.' }
        format.json { render json: @analysis, status: :created, location: @analysis }
      else
        format.html { render action: "new" }
        format.json { render json: @analysis.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /analyses/1
  # PUT /analyses/1.json
  def update
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      if @analysis.update_attributes(params[:analysis])
        format.html { redirect_to @analysis, notice: 'Analysis was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @analysis.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /analyses/1
  # DELETE /analyses/1.json
  def destroy
    @analysis = Analysis.find(params[:id])
    @analysis.destroy

    respond_to do |format|
      format.html { redirect_to analyses_url }
      format.json { head :no_content }
    end
  end

  # Controller for submitting the action via post.  This right now only works with the API
  # and will only return a JSON response based on whether or not the analysis has been
  # queued into Delayed Jobs
  def action
    @analysis = Analysis.find(params[:id])

    result = {}
    if @analysis.start_r_and_run_sample
      result[:code] = 200
      @analysis.status = 'queued'
      result[:analysis] = @analysis
    else
      result[:code] = 500
      @analysis.status = 'error'
      # TODO: save off the error
    end

    @analysis.save!
    respond_to do |format|
    #  format.html # new.html.erb
      format.json { render json: result }
    end
  end

  def status
    @analysis = Analysis.find(params[:id])

    dps = nil
    if params[:jobs].nil?
      dps = @analysis.data_points
    else
      dps = @analysis.data_points.where(status: params[:jobs])
    end



    #@analysis.start_r_and_run_sample

    #redirect_to analysis_url(@analysis)

    respond_to do |format|
      #  format.html # new.html.erb
      format.json { render json: {data_points: dps } }
    end
  end

  def upload
    @analysis = Analysis.find(params[:id])

    @analysis.seed = params[:file]

    respond_to do |format|
      if @analysis.save
        format.json { render json: @analysis, status: :created, location: @analysis }
      else
        format.json { render json: @analysis.errors, status: :unprocessable_entity }
      end
    end

  end
end
