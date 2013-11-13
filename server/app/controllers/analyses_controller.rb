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
      format.json { render json: {:analysis => @analysis, :metadata => @analysis[:os_metadata]} }
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

    @analysis = Analysis.new(params[:analysis])

    # Need to pull out the variables that are in this analysis so that we can stitch the problem
    # back together when it goes to run
    logger.info("pulling out os variables")
    @analysis.pull_out_os_variables()

    respond_to do |format|
      if @analysis.save!
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
    project_id = @analysis.project
    @analysis.destroy

    respond_to do |format|
      format.html { redirect_to project_path(project_id) }
      format.json { head :no_content }
    end
  end

  # Controller for submitting the action via post.  This right now only works with the API
  # and will only return a JSON response based on whether or not the analysis has been
  # queued into Delayed Jobs
  def action
    @analysis = Analysis.find(params[:id])
    logger.info("action #{params.inspect}")
    params[:analysis_type].nil? ? @analysis_type = 'batch_run' : @analysis_type = params[:analysis_type]

    logger.info("without delay was set #{params[:without_delay]} with class #{params[:without_delay].class}")
    options = params.symbolize_keys # read the deaults from the HTTP request
    options[:simulate_data_point_filename] = params[:simulate_data_point_filename] if params[:simulate_data_point_filename]
    options[:x_objective_function] = @analysis['x_objective_function'] if @analysis['x_objective_function']
    options[:y_objective_function] = @analysis['y_objective_function'] if @analysis['y_objective_function']

    logger.info("After parsing JSON arguments and default values, analysis will run with the following options #{options}")

    if params[:analysis_action] == 'start'
      params[:without_delay].to_s == 'true' ? no_delay = true : no_delay = false
      res = @analysis.run_analysis(no_delay, @analysis_type, options)
      result = {}
      if res[0]
        result[:code] = 200
        result[:analysis] = @analysis
      else
        result[:code] = 500
        result[:error] = res[1]
      end

      respond_to do |format|
        if result[:code] == 200
          format.json { render json: result }
          format.html { redirect_to @analysis, notice: 'Analysis was started.' }
        else
          format.json { render json: result }
          format.html { redirect_to @analysis, notice: 'Analysis was NOT started.' }
        end
      end
    elsif params[:analysis_action] == 'stop'
      res = @analysis.stop_analysis
      result = {}
      if res[0]
        result[:code] = 200
        result[:analysis] = @analysis
      else
        result[:code] = 500
        result[:error] = res[1]
      end

      respond_to do |format|
        if result[:code] == 200
          format.json { render json: result }
          format.html { redirect_to @analysis, notice: 'Analysis flag changed to stop. Will wait until the last submitted run finishes before killing.' }
        else
          format.json { render json: result }
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
      format.json { render json: {:analysis => {:status => @analysis.status}, data_points: dps.map { |k| {:_id => k.id, :status => k.status} }} }
    end
  end

  def download_status
    @analysis = Analysis.find(params[:id])

    dps = nil
    if params[:downloads].nil?
      dps = @analysis.data_points.where(download_status: 'completed')
    else
      dps = @analysis.data_points.where(download_status: params[:downloads])
    end

    respond_to do |format|
      #  format.html # new.html.erb
      format.json { render json: {:analysis => {status: @analysis.status}, data_points: dps.map { |k| {:_id => k.id, :status => k.status, :download_status => k.download_status} }} }
    end
  end

  def upload
    @analysis = Analysis.find(params[:id])

    if @analysis
      @analysis.seed_zip = params[:file]
    end

    respond_to do |format|
      if @analysis.save
        format.json { render json: @analysis, status: :created, location: @analysis }
      else
        format.json { render json: @analysis.errors, status: :unprocessable_entity }
      end
    end

  end

  def debug_log
    @analysis = Analysis.find(params[:id])

    @rserve_log = File.read(File.join(Rails.root, 'log', 'Rserve.log'))

    exclude_fields = [:_id, :user, :password]
    @workers = ComputeNode.where(node_type: 'worker').map { |n| n.as_json(:except => exclude_fields) }
    @server = ComputeNode.where(node_type: 'server').first.as_json(:expect => exclude_fields)

    respond_to do |format|
      format.html # debug_log.html.erb
      format.json { render json: log_message }
    end

  end

  def new_view
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      exclude_fields = [
          :os_metadata,
          :problem,
      ]
      include_fields = [
          :variables,
          :measures #=> {:include => :variables}
      ]
      #  format.html # new.html.erb
      format.json { render json: {:analysis => @analysis.as_json(:except => exclude_fields, :include => include_fields)} }
    end
  end

  def plot_parallelcoordinates
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # debug_log.html.erb
    end
  end

  def plot_scatter
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # results_scatter.html.erb
    end
  end

  def plot_xy
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # results_scatter.html.erb
    end
  end

  def plot_data
    @analysis = Analysis.find(params[:id])

    # Get the mappings of the variables that were used. Move this to the datapoint class
    @mappings = get_superset_of_variables(@analysis)
    @plot_data = get_plot_data(@analysis, @mappings)

    respond_to do |format|
      format.json { render json: {:mappings => @mappings, :data => @plot_data} }
    end
  end

  def page_data
    @analysis = Analysis.find(params[:id])

    # once we know that for all the buildings.
    #@time_zone = "America/Denver"
    #@data.each do |d|
    #  time, tz_abbr = Util::Date.fake_zone_in_utc(d[:time].to_i / 1000, @time_zone)
    #  d[:fake_tz_time] = time.to_i * 1000
    #  d[:tz_abbr] = tz_abbr
    #end

    respond_to do |format|
      format.json do
        fields = [
            :name,
            :data_points,
            :analysis_type,
            :status,
            :start_time,
            :end_time,
            :seed_zip,
            :results,
            :run_start_time,
            :run_end_time,
            :openstudio_datapoint_file_name
        ]

        render json: {:analysis => @analysis.as_json(:only => fields, :include => :data_points)}
        #render json: {:analysis => @analysis.as_json(:only => fields, :include => :data_points ), :metadata => @analysis[:os_metadata]}
      end
    end
  end

  def download_csv
    @analysis = Analysis.find(params[:id])

    write_and_send_csv(@analysis)
  end

  def download_rdata
    @analysis = Analysis.find(params[:id])

    write_and_send_rdata(@analysis)
  end


  protected

  # This method is not optimized at all.  It iterates over all data points variable values and pulls 
  # out the variable information.  Need to push this into the model and be much smarter 
  # about the query.  At least the query is calling 'only'.
  def get_superset_of_variables(analysis)
    mappings = {}

    # this is a little silly right now.  a datapoint is really really complete after the download status and status are set to complete
    dps = analysis.data_points.where({download_status: 'completed', status: 'completed'}).only(:set_variable_values)
    dps.each do |dp|
      if dp.set_variable_values
        dp.set_variable_values.each_key do |key|
          v = Variable.where(uuid: key).first
          mappings[key] = v.name.gsub(" ", "_") if v
        end
      end
    end

    Rails.logger.info mappings

    mappings
  end

  # Simple method that takes in the analysis (to get the datapoints) and the variable map hash to construct
  # a useful JSON for plotting (and exporting to CSV)
  def get_plot_data(analysis, mappings)
    # TODO: put the work on the database with projection queries (i.e. .only(:name, :age))
    # and this is just an ugly mapping, sorry all.

    plot_data = []
    if @analysis.analysis_type == "sequential_search"
      dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
      dps = dps.rotate(1) # put the starting point on top
    else
      dps = @analysis.data_points.all
    end
    dps.each do |dp|
      if dp['results']
        dp_values = {}

        dp_values["data_point_uuid"] = data_point_path(dp.id)

        # lookup input value names
        if dp.set_variable_values
          dp.set_variable_values.each do |k, v|
            dp_values["#{mappings[k]}"] = v
          end
        end

        # outputs -- map these by hand right now because I don't want to parse the entire results into
        # the dp_values hash
        dp_values["total_energy"] = dp['results']['total_energy'] || dp['results']['total_site_energy']
        dp_values["interior_lighting_electricity"] = dp['results']['interior_lighting_electricity'] if dp['results']['interior_lighting_electricity']
        dp_values["total_life_cycle_cost"] = dp['results']['total_life_cycle_cost']
        dp_values["iteration"] = dp['iteration'] if dp['iteration']

        plot_data << dp_values
      end
    end

    plot_data
  end

  def write_and_send_csv(analysis)
    require 'csv'

    mappings = get_superset_of_variables(analysis)
    data = get_plot_data(analysis, mappings)
    filename = "#{analysis.uuid}.csv"
    csv_string = CSV.generate do |csv|
      icnt = 0
      data.each do |dp|
        icnt += 1
        # Write out the header if this is the first datapoint
        csv << dp.keys if icnt == 1
        csv << dp.values
      end
    end

    send_data csv_string, :filename => filename, :type => 'text/csv; charset=iso-8859-1; header=present', :disposition => "attachment"
  end


  def write_and_send_rdata(analysis)
    mappings = get_superset_of_variables(analysis)
    data = get_plot_data(analysis, mappings)
    download_filename = "#{analysis.name}.RData"
    data_frame_name = analysis.name.downcase.gsub(" ", "_")
    Rails.logger.info("Data frame name will be #{data_frame_name}")

    # need to convert array of hash to hash of arrays
    # [{a: 1, b: 2}, {a: 3, b: 4}] to {a: [1,2], b: [3,4]}
    out_hash = data.each_with_object(Hash.new([])) do |h1, h|
      h1.each { |k, v| h[k] = h[k] + [v] }
    end

    # Todo, move this to a helper method of some sort under /lib/anlaysis/r/...
    require 'rserve/simpler'
    r = Rserve::Simpler.new
    r.command(data_frame_name.to_sym => out_hash.to_dataframe) do
      %Q{
            temp <- tempfile('rdata', tmpdir="/tmp")   
            save('#{data_frame_name}', file = temp)   
            Sys.chmod(temp, mode = "0777", use_umask = TRUE)
         }
    end
    tmp_filename = r.converse('temp')
    
    if File.exists?(tmp_filename)
      send_data File.open(tmp_filename).read, :filename => download_filename, :type => 'text/csv; charset=iso-8859-1; header=present', :disposition => "attachment"
    else
      raise "could not create R dataframe"
    end
    

  end

end
