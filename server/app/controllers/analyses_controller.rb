require 'will_paginate/array'
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
    per_page = 50

    @analysis = Analysis.find(params[:id])

    #tab status
    @status = 'all'
    if !params[:status].nil?
        @status = params[:status]
    end

    logger.debug("!!!!params STATUS is: #{params[:status]}")
    logger.debug("!!ALL SEARCH: #{params[:all_search]}")

    #blanks should be saved as nil or it will crash
    @all_page = @status == 'all' ? params[:page] : params[:all_page]
    @all_page = @all_page == '' ? nil : @all_page
    @completed_page = @status == 'completed' ? params[:page] : params[:completed_page]
    @completed_page = @completed_page == '' ? nil : @completed_page
    @running_page = @status == 'running' ? params[:page] : params[:running_page]
    @running_page = @running_page == '' ? nil : @running_page
    @queued_page = @status == 'queued' ? params[:page] : params[:queued_page]
    @queued_page = @queued_page == '' ? nil : @queued_page
    @na_page = @status == 'na' ? params[:page] : params[:na_page]
    @na_page = @na_page == '' ? nil : @na_page

    @all_sims_total = @analysis.search(params[:all_search], 'all')
    @all_sims = @all_sims_total.paginate(:page => @all_page, :per_page => per_page, :total_entries => @all_sims_total.count)

    @completed_sims_total = @analysis.search(params[:completed_search], 'completed')
    logger.debug("!!! @completed_sims_total: #{@completed_sims_total.count}")
    @completed_sims = @completed_sims_total.paginate(:page => @completed_page, :per_page => per_page, :total_entries => @completed_sims_total.count)

    @running_sims_total = @analysis.search(params[:running_search],'started')
    @running_sims = @running_sims_total.paginate(:page => @running_page, :per_page => per_page, :total_entries => @running_sims_total.count)

    @queued_sims_total = @analysis.search(params[:queued_search], 'queued')
    @queued_sims = @queued_sims_total.paginate(:page => @queued_page, :per_page => per_page, :total_entries => @queued_sims_total.count)

    @na_sims_total = @analysis.search(params[:na_search], 'na')
    @na_sims = @na_sims_total.paginate(:page => @na_page, :per_page => per_page, :total_entries => @na_sims_total.count)


    case @status
    when 'all'
      @status_simulations = @all_sims
    when 'completed'
      @status_simulations = @completed_sims
    when 'running'
      @status_simulations = @running_sims
    when 'queued'
      @status_simulations = @queued_sims
    when 'na'
      @status_simulations = @na_sims
    end

    @objective_functions = []

    #todo: move this to the page_data or another secondary call
    if @analysis
      if @analysis.output_variables
        @analysis.output_variables.each do |ov|
          if ov['objective_function']
            @objective_functions << ov
          end
        end
      end

      if @objective_functions.empty?
        # todo: we need to standardize on the result of this
        if @analysis['num_measure_groups']
          @objective_functions << {'display_name' => "Total Site Energy (EUI)", 'name' => "total_site_energy", 'units' => "EUI"}
        else
          @objective_functions << {'display_name' => "Total Site Energy (EUI)", 'name' => "total_energy", 'units' => "EUI"}
        end
        @objective_functions << {'display_name' => "Total Life Cycle Cost", 'name' => "total_life_cycle_cost", 'units' => "USD"}
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: {:analysis => @analysis} }
      format.js
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
    options = params.symbolize_keys # read the defaults from the HTTP request
    options[:run_data_point_filename] = params[:run_data_point_filename] if params[:run_data_point_filename]

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

  def plot_radar
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # results_scatter.html.erb
    end
  end

  def plot_data
    @analysis = Analysis.find(params[:id])

    # Get the mappings of the variables that were used. Move this to the datapoint class
    @mappings = @analysis.get_superset_of_input_variables
    @plotvars = get_plot_variables(@analysis)
    @plot_data = get_plot_data(@analysis, @mappings)
    @plot_data_radar = get_plot_data_radar(@analysis, @mappings)

    respond_to do |format|
      format.json { render json: {:mappings => @mappings, :radardata => @plot_data_radar, :plotvars => @plotvars, :data => @plot_data} }
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
            :openstudio_datapoint_file_name,
            :output_variables
        ]

        render json: {:analysis => @analysis.as_json(:only => fields, :include => :data_points)}
        #render json: {:analysis => @analysis.as_json(:only => fields, :include => :data_points ), :metadata => @analysis[:os_metadata]}
      end
    end
  end

  def download_data
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.csv do
        write_and_send_csv(@analysis)
      end
      format.rdata do
        write_and_send_rdata(@analysis)
      end
    end
  end

  def download_variables
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.csv do
        redirect_to @analysis, notice: "CSV not yet supported for downloading variables" 
        #write_and_send_csv(@analysis)
      end
      format.rdata do
        write_and_send_input_variables_rdata(@analysis)
      end
    end
  end

  protected

  def get_plot_variables(analysis)
    plotvars = []
    ovs = @analysis.output_variables
    ovs.each do |ov|
      if ov['objective_function']
        plotvars << ov['name']
      end
    end
    Rails.logger.info plotvars
    plotvars
  end

  def get_plot_data_radar(analysis, mappings)
    # TODO: put the work on the database with projection queries (i.e. .only(:name, :age))
    # and this is just an ugly mapping, sorry all.

    ovs = @analysis.output_variables
    plot_data_radar = []
    if @analysis.analysis_type == "sequential_search"
      dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
      dps = dps.rotate(1) # put the starting point on top
    else
      dps = @analysis.data_points.all
    end
    dps.each do |dp|
      if dp['results']
        plot_data = []
        ovs.each do |ov|
          if ov['objective_function']
            dp_values = {}
            dp_values["axis"] = ov['name']
            dp_values["value"] = dp['results'][ov['name']]
            plot_data << dp_values
          end
        end

        plot_data_radar << plot_data
      end
    end

    plot_data_radar
  end


  # Simple method that takes in the analysis (to get the datapoints) and the variable map hash to construct
  # a useful JSON for plotting (and exporting to CSV/R-dataframe)
  # The results is the same as the varaibles hash which defines which results to export.  If nil it will only
  # export the results that in the output_variables hash
  def get_plot_data(analysis, variables, results = nil)
    plot_data = []
    if @analysis.analysis_type == "sequential_search"
      dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
      dps = dps.rotate(1) # put the starting point on top
    else
      dps = @analysis.data_points.all
    end

    # load in the output variables that are requested (including objective functions)
    ovs = @analysis.output_variables

    dps.each do |dp|
      # the datapoint is considered complete if it has results set
      if dp['results']
        dp_values = {}

        dp_values["data_point_uuid"] = data_point_path(dp.id)

        # lookup input value names (from set_variable_values)
        # todo: push this work into the database
        if dp.set_variable_values
          variables.each do |k, v|
            dp_values[v] = dp.set_variable_values[k] ? dp.set_variable_values[k] : nil
          end
        end

        if results
          # this will eventually be two levels (which will need to be collapsable for column vectors)
          results.each do |key, _|
            dp_values[key] = dp.results[key] ? dp.results[key] : nil
          end
        else
          # output all output variables in the array of hashes (regardless if it is an objective function or not)
          ovs.each do |ov|
            dp_values[ov['name']] = dp['results'][ov['name']] if dp['results'][ov['name']]
          end
        end


        # TEMP -- put out the total_energy in the JSON in case it isn't in the output_variables hash
        dp_values["total_energy"] = dp['results']['total_energy'] || dp['results']['total_site_energy']

        plot_data << dp_values
      end
    end

    plot_data
  end

  def write_and_send_csv(analysis)
    require 'csv'

    variable_mappings = analysis.get_superset_of_input_variables
    result_mappings = analysis.get_superset_of_result_variables
    Rails.logger.info "RESULTS MAPPING was #{result_mappings}"
    data = get_plot_data(analysis, variable_mappings, result_mappings)
    filename = "#{analysis.name}.csv"
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

  def write_and_send_input_variables_rdata(analysis)
    variable_mappings = analysis.get_superset_of_input_variables
    download_filename = "#{analysis.name}_input_variables.RData"
    data_frame_name = "#{analysis.name.downcase.gsub(" ", "_")}_input_variables"
    Rails.logger.info("Data frame name will be #{data_frame_name}")

    # need to convert array of hash to hash of arrays
    out_hash = {}
    out_hash['measure_name'] = []
    out_hash['variable_name'] = []
    out_hash['variable_display_name'] = []
    out_hash['value_type'] = []
    out_hash['units'] = []
    out_hash['type_of_variable'] = []

    variable_mappings.each do |k, v|
      variable = Variable.find(k)
      out_hash['measure_name'] << variable.measure.name ? variable.measure.name : nil
      out_hash['variable_name'] << variable.name ? variable.name : nil
      out_hash['variable_display_name'] << variable['display_name'] ? variable['display_name'] : nil
      out_hash['value_type'] << variable['value_type'] ? variable['value_type'] : nil
      out_hash['units'] << variable['units'] ? variable['units'] : nil
      if variable['variable']
        out_hash['type_of_variable'] << 'variable'
      elsif variable['pivot']
        out_hash['type_of_variable'] << 'pivot'
      elsif variable['static']
        out_hash['type_of_variable'] << 'static'
      else
        out_hash['type_of_variable'] << 'other'
      end
    end

    Rails.logger.info("outhash is #{out_hash}")

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
      send_data File.open(tmp_filename).read, :filename => download_filename, :type => 'application/rdata; header=present', :disposition => "attachment"
    else
      raise "could not create R dataframe"
    end
  end

  def write_and_send_rdata(analysis)
    variable_mappings = analysis.get_superset_of_input_variables
    result_mappings = analysis.get_superset_of_result_variables
    data = get_plot_data(analysis, variable_mappings, result_mappings)
    download_filename = "#{analysis.name}.RData"
    data_frame_name = analysis.name.downcase.gsub(" ", "_")
    Rails.logger.info("Data frame name will be #{data_frame_name}")

    # need to convert array of hash to hash of arrays
    # [{a: 1, b: 2}, {a: 3, b: 4}] to {a: [1,2], b: [3,4]} 
    out_hash = data.each_with_object(Hash.new([])) do |h1, h|
      h1.each { |k, v| h[k] = h[k] + [v] }
    end

    Rails.logger.info("outhash is #{out_hash}")

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
      send_data File.open(tmp_filename).read, :filename => download_filename, :type => 'application/rdata; header=present', :disposition => "attachment"
    else
      raise "could not create R dataframe"
    end
  end

end
