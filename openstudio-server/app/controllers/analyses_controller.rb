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
      format.json { render json: { :analysis => @analysis, :metadata => @analysis[:os_metadata] } }
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
    params[:analysis].merge!(:project_id => project_id)

    # save off the metadata as a child of the analysis right now... eventually move analysis
    # underneath metadata
    params[:analysis].merge!(:os_metadata => params[:metadata])
    File.open("received_json.json","w") { |f| f << JSON.pretty_generate(params) }

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
    logger.info("action #{params.inspect}")

    result = {}
    if params[:analysis_action] == 'start'
      logger.info("Initializing workers in database")
      @analysis.initialize_workers

      logger.info("queuing up analysis #{@analysis}")
      params[:without_delay] == 'true' ? no_delay = true : no_delay = false

      if !no_delay
        if @analysis.start_r_and_run_sample
          result[:code] = 200
          result[:analysis] = @analysis
        else
          result[:code] = 500
        end
      else
        if @analysis.start_r_and_run_sample_without_delay
          result[:code] = 200
          result[:analysis] = @analysis
        else
          result[:code] = 500
        end
      end

      respond_to do |format|
        #  format.html # new.html.erb
        format.json { render json: result }
        if result[:code] == 200
          format.html { redirect_to @analysis, notice: 'Analysis was started.' }
        else
          format.html { redirect_to @analysis, notice: 'Analysis was NOT started.' }
        end
      end
    elsif params[:analysis_action] == 'stop'
      if @analysis.stop_analysis
        result[:code] = 200
        result[:analysis] = @analysis
      else
        result[:code] = 500
        # TODO: save off the error
      end


      respond_to do |format|
        #  format.html # new.html.erb
        format.json { render json: result }
        if result[:code] == 200
          format.html { redirect_to @analysis, notice: 'Analysis flag changed to stop. Will wait until the last run finishes.' }
        else
          format.html { redirect_to @analysis, notice: 'Analysis flag did NOT change.' }
        end
      end
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

    respond_to do |format|
      #  format.html # new.html.erb
      format.json { render json: { :analysis => { :status => @analysis.status}, data_points: dps.map{ |k| {:_id => k.id, :status => k.status } } } }
    end
  end

  def upload
    @analysis = Analysis.find(params[:id])

    @analysis.seed_zip = params[:file]

    respond_to do |format|
      if @analysis.save
        format.json { render json: @analysis, status: :created, location: @analysis }
      else
        format.json { render json: @analysis.errors, status: :unprocessable_entity }
      end
    end

  end
end
