require 'will_paginate/array'
require 'core_extensions'

class AnalysesController < ApplicationController
  # GET /analyses
  # GET /analyses.json
  def index
    if params[:project_id].nil?
      @analyses = Analysis.all
      @project = nil

    else
      @project = Project.find(params[:project_id])
      @analyses = @project.analyses

    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @analyses }
    end
  end

  # GET /analyses/1
  # GET /analyses/1.json
  def show
    # for pagination
    per_page = 50

    @analysis = Analysis.find(params[:id])

    if @analysis

      # tab status
      @status = 'all'
      unless params[:status].nil?
        @status = params[:status]
      end

      # blanks should be saved as nil or it will crash
      @all_page = @status == 'all' ? params[:page] : params[:all_page]
      @all_page = @all_page == '' ? nil : @all_page
      @completed_page = @status == 'completed' ? params[:page] : params[:completed_page]
      @completed_page = @completed_page == '' ? nil : @completed_page
      @started_page = @status == 'started' ? params[:page] : params[:started_page]
      @started_page = @started_page == '' ? nil : @started_page
      @queued_page = @status == 'queued' ? params[:page] : params[:queued_page]
      @queued_page = @queued_page == '' ? nil : @queued_page
      @na_page = @status == 'na' ? params[:page] : params[:na_page]
      @na_page = @na_page == '' ? nil : @na_page

      @all_sims_total = @analysis.search(params[:all_search], 'all')
      # if "view_all" param is set, use @all_sims_total instead of @all_sims (for ALL tab only)
      @view_all = 0
      if params[:view_all] && params[:view_all] == '1'
        @all_sims = @all_sims_total
        @view_all = 1
      else
        @all_sims = @all_sims_total.paginate(page: @all_page, per_page: per_page, total_entries: @all_sims_total.count)
      end

      @completed_sims_total = @analysis.search(params[:completed_search], 'completed')
      @completed_sims = @completed_sims_total.paginate(page: @completed_page, per_page: per_page, total_entries: @completed_sims_total.count)

      @started_sims_total = @analysis.search(params[:started_search], 'started')
      @started_sims = @started_sims_total.paginate(page: @started_page, per_page: per_page, total_entries: @started_sims_total.count)

      @queued_sims_total = @analysis.search(params[:queued_search], 'queued')
      @queued_sims = @queued_sims_total.paginate(page: @queued_page, per_page: per_page, total_entries: @queued_sims_total.count)

      @na_sims_total = @analysis.search(params[:na_search], 'na')
      @na_sims = @na_sims_total.paginate(page: @na_page, per_page: per_page, total_entries: @na_sims_total.count)

      case @status
        when 'all'
          @status_simulations = @all_sims
        when 'completed'
          @status_simulations = @completed_sims
        when 'started'
          @status_simulations = @started_sims
        when 'queued'
          @status_simulations = @queued_sims
        when 'na'
          @status_simulations = @na_sims
      end

      @objective_functions = @analysis.variables.where(:objective_function => true).order_by(:objective_function.asc, :sample.asc)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: {analysis: @analysis} }
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
    params[:analysis].merge!(project_id: project_id)

    @analysis = Analysis.new(params[:analysis])

    # Need to pull out the variables that are in this analysis so that we can stitch the problem
    # back together when it goes to run
    logger.info('pulling out os variables')
    @analysis.pull_out_os_variables

    respond_to do |format|
      if @analysis.save!
        format.html { redirect_to @analysis, notice: 'Analysis was successfully created.' }
        format.json { render json: @analysis, status: :created, location: @analysis }
      else
        format.html { render action: 'new' }
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
        format.html { render action: 'edit' }
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

  # stop analysis button action
  def stop
    @analysis = Analysis.find(params[:id])
    res = @analysis.stop_analysis

    respond_to do |format|
      if res[0]
        format.html { redirect_to @analysis, notice: 'Analysis flag changed to stop. Will wait until the last submitted run finishes before killing.' }
      else
        format.html { redirect_to @analysis, notice: 'Analysis flag did NOT change.' }
      end
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
    if params[:jobs]
      dps = @analysis.data_points.where(status: params[:jobs])
    else
      dps = @analysis.data_points
    end

    respond_to do |format|
      #  format.html # new.html.erb
      format.json { render json: {
          analysis: {
              status: @analysis.status,
              analysis_type: @analysis.analysis_type
          },
          data_points: dps.map { |k| {_id: k.id, status: k.status} }} }
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
      format.json { render json: {analysis: {status: @analysis.status}, data_points: dps.map { |k| {_id: k.id, status: k.status, download_status: k.download_status} }} }
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
    @workers = ComputeNode.where(node_type: 'worker').map { |n| n.as_json(except: exclude_fields) }
    @server = ComputeNode.where(node_type: 'server').first.as_json(expect: exclude_fields)

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
          :measures # => {:include => :variables}
      ]
      #  format.html # new.html.erb
      format.json { render json: {analysis: @analysis.as_json(except: exclude_fields, include: include_fields)} }
    end
  end

  # TODO: this can be deprecated?
  # TODO: Remove this and use a general plot_data method
  def plot_parallelcoordinates
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # plot_parallelcoordinates.html.erb
    end
  end

  # other version with form to control what data to plot
  # TODO: Remove this and use a general plot_data method
  def plot_parallelcoordinates2
    @analysis = Analysis.find(params[:id])
    # mappings + plotvars make the superset of chart variables
    @mappings = @analysis.get_superset_of_input_variables
    @plotvars = get_plot_variables(@analysis)

    # variables represent the variables we want graphed. Nil = all
    @variables = params[:variables] ? params[:variables] : nil

    # whatever is defined as variables here should be the only returned data
    @plot_data = get_plot_data2(@analysis, @mappings, @plotvars, @variables)

    respond_to do |format|
      format.html # plot_parallelcoordinates.html.erb
    end
  end

  # interactive XY plot: choose x and y variables
  # TODO: Remove this and use a general plot_data method
  def plot_xy_interactive
    @analysis = Analysis.find(params[:id])

    @mappings = @analysis.get_superset_of_input_variables
    @plotvars = get_plot_variables(@analysis)

    @allvars = []
    @mappings.each do |key, val|
      @allvars << val
    end
    @plotvars.each do |val|
      @allvars << val
    end

    # variables represent the variables we want graphed. Nil = all
    @variables = []
    if params[:variables].nil?
      @variables << @plotvars[0] << @plotvars[1]
    else
      if params[:variables][:x]
        @variables << params[:variables][:x]
      else
        @variables << @plotvars[0]
      end
      if params[:variables][:y]
        @variables << params[:variables][:y]
      else
        @variables << @plotvars[0]
      end
    end

    respond_to do |format|
      format.html # plot_xy.html.erb
    end
  end

  # The results is the same as the variables hash which defines which results to export.  If nil it will only
  # export the results that are in the output_variables hash
  # TODO: Remove this and use a general plot_data method
  def get_plot_data2(analysis, variables, outputs, results = nil)
    plot_data = []
    if @analysis.analysis_type == 'sequential_search'
      dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
      dps = dps.rotate(1) # put the starting point on top
    else
      dps = @analysis.data_points.all
    end

    dps.each do |dp|
      # the datapoint is considered complete if it has results set
      if dp.results
        dp_values = {}
        dp_values['data_point_uuid'] = data_point_path(dp.id)

        if results
          # input variables: not in dp['results']
          if dp.set_variable_values
            variables.each do |k, v|
              if results.include?(v)
                logger.info("value: #{dp.set_variable_values[k]}")
                dp_values[v] = dp.set_variable_values[k] ? dp.set_variable_values[k] : nil
              end
            end
          end

          # output variables. Don't overwrite input variables from above
          results.each do |key, _|
            # TEMP: special case for "total_energy" (could also be called total_site_energy)
            if key == 'total_energy' and !dp.results[key]
              dp_values[key] = dp['results']['total_site_energy']
            elsif !dp_values[key]
              dp_values[key] = dp['results'][key] ? dp['results'][key] : nil
            end
          end

        else
          # go through variables and output variables
          if dp.set_variable_values
            variables.each do |k, v|
              dp_values[v] = dp.set_variable_values[k] ? dp.set_variable_values[k] : nil
            end
          end
          outputs.each do |ov|
            # TEMP: special case for "total_energy" (could be called total_site_energy)
            if ov == 'total_energy' and !dp['results'][ov]
              dp_values['total_energy'] = dp['results']['total_site_energy']
            else
              dp_values[ov] = dp['results'][ov] if dp['results'][ov]
            end
          end
        end

        plot_data << dp_values
      end
    end

    plot_data
  end

  # TODO: Remove this and use a general plot_data method
  def plot_data_xy
    # TODO: either figure out how to ajaxify the json directly to reduce db calls
    # TODO: or remove data from the @plot_data variable (we are returning everything for now)
    @analysis = Analysis.find(params[:id])

    # Get the mappings of the variables that were used. Move this to the datapoint class
    @mappings = @analysis.get_superset_of_input_variables

    # if no variables are specified, use first one(s) in the list
    if params[:variables].nil?
      @plotvars = get_plot_variables(@analysis)
    else
      @plotvars = params[:variables].split(',')
    end
    @plot_data = get_plot_data(@analysis, @mappings)

    respond_to do |format|
      format.json { render json: {mappings: @mappings, plotvars: @plotvars, data: @plot_data} }
    end
  end

  # TODO: Remove this and use a general plot_data method
  def plot_scatter
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # plot_scatter.html.erb
    end
  end

  # TODO: Remove this and use a general plot_data method
  def plot_xy
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # plot_xy.html.erb
    end
  end

  # TODO: Remove this and use a general plot_data method
  def plot_radar
    @analysis = Analysis.find(params[:id])
    if params[:datapoint_id]
      @datapoint = DataPoint.find(params[:datapoint_id])
    else

      if @analysis.analysis_type == 'sequential_search'
        @datapoint = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc).last
      else
        @datapoint = @analysis.data_points.all.order_by(:run_end_time.desc).first
      end
    end

    respond_to do |format|
      format.html # plot_radar.html.erb
    end
  end

  # TODO: Remove this and use a general plot_data method
  def plot_bar
    @analysis = Analysis.find(params[:id])
    if params[:datapoint_id]
      @datapoint = DataPoint.find(params[:datapoint_id])
    else

      if @analysis.analysis_type == 'sequential_search'
        @datapoint = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc).last
      else
        @datapoint = @analysis.data_points.all.order_by(:run_end_time.desc).first
      end
    end

    respond_to do |format|
      format.html # plot_bar.html.erb
    end
  end

  # TODO: Remove this and use a general plot_data method
  def plot_data_bar
    # TODO: this should always take a datapoint param
    @analysis = Analysis.find(params[:id])

    if params[:datapoint_id]
      # plot a specific datapoint
      @plot_data, @datapoint = get_plot_data_bar(@analysis, params[:datapoint_id])
    else
      # plot the latest datapoint
      @plot_data, @datapoint = get_plot_data_bar(@analysis)
    end
    respond_to do |format|
      format.json { render json: {datapoint: {id: @datapoint.id, name: @datapoint.name}, bardata: @plot_data} }
    end
  end

  # TODO: Remove this and use a general plot_data method
  def plot_data_radar
    # TODO: this should always take a datapoint param
    @analysis = Analysis.find(params[:id])

    if params[:datapoint_id]
      # plot a specific datapoint
      @plot_data, @datapoint = get_plot_data_radar(@analysis, params[:datapoint_id])
    else
      # plot the latest datapoint
      @plot_data, @datapoint = get_plot_data_radar(@analysis)
    end
    respond_to do |format|
      format.json { render json: {datapoint: {id: @datapoint.id, name: @datapoint.name}, radardata: @plot_data} }
    end
  end

  def plot_data
    @analysis = Analysis.find(params[:id])

    @mappings = @analysis.get_superset_of_input_variables
    @plotvars = get_plot_variables(@analysis)
    @plot_data = get_plot_data(@analysis, @mappings)

    respond_to do |format|
      format.json { render json: {mappings: @mappings, plotvars: @plotvars, data: @plot_data} }
    end
  end

  # This needs to be updated, but the plan of this method is to provide all the plot-data (or export data) in
  # a JSON format that can be consumed by various users such as the bar plots, parallel plots, pairwise plots, etc.
  # Once this is functional, then remove the old "plot_data". Remove route too!
  def plot_data_v2
    analysis = Analysis.find(params[:id])
    variables, plot_data = get_plot_data_v2(analysis)

    respond_to do |format|
      format.json { render json: {variables: variables, data: plot_data} }
    end
  end

  def page_data
    @analysis = Analysis.find(params[:id])

    # once we know that for all the buildings.
    # @time_zone = "America/Denver"
    # @data.each do |d|
    #  time, tz_abbr = Util::Date.fake_zone_in_utc(d[:time].to_i / 1000, @time_zone)
    #  d[:fake_tz_time] = time.to_i * 1000
    #  d[:tz_abbr] = tz_abbr
    # end

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

        render json: {analysis: @analysis.as_json(only: fields, include: :data_points)}
        # render json: {:analysis => @analysis.as_json(:only => fields, :include => :data_points ), :metadata => @analysis[:os_metadata]}
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

  def download_all_data_points
    analysis = Analysis.find(params[:id])

    # use a system call to zip up all the results
    # TODO: this may eventually timeout

    time_stamp = Time.now.to_i
    save_file = "/tmp/#{analysis.name}_datapoints_#{time_stamp}.zip"
    resp = `zip #{save_file} -j --exclude='*reports.zip' /mnt/openstudio/analysis_#{analysis.id}/data_point_*.zip`

    if $?.exitstatus == 0
      data_point_zip_data = File.read(save_file)
      send_data data_point_zip_data, filename: File.basename(save_file), type: 'application/zip; header=present', disposition: 'attachment'
    else
      redirect_to analysis_path(analysis), notice: "Error zipping up files"
    end

  end

  protected

  # TODO: Update this to pull from the Variables model with the field :visualize set to true *see plot_data_v2
  def get_plot_variables(analysis)
    plotvars = []
    ovs = @analysis.output_variables
    ovs.each do |ov|
      if ov['objective_function']
        plotvars << ov['name']
      end
    end

    # add "total energy" if it's not already in the output variables
    unless plotvars.include?('total_energy')
      plotvars.insert(0, 'total_energy')
    end

    Rails.logger.info plotvars
    plotvars
  end

  # Data for Bar chart of objective functions actual values vs target values
  # "% error"-like, but negative when actual is less than target and positive when it is more than target
  # for now: only plots the latest datapoint
  def get_plot_data_bar(analysis, datapoint_id = nil)
    ovs = analysis.output_variables
    plot_data_bar = []

    if datapoint_id
      dp = analysis.data_points.find(datapoint_id)
    else
      if analysis.analysis_type == 'sequential_search'
        dp = analysis.data_points.all.order_by(:iteration.asc, :sample.asc).last
      else
        dp = analysis.data_points.all.order_by(:run_end_time.desc).first
      end
    end

    if dp['results']
      ovs.each do |ov|
        if ov['objective_function']
          dp_values = []
          dp_values << ov['name']
          dp_values << ((dp['results'][ov['name']] - ov['objective_function_target']) / ov['objective_function_target'] * 100).round(1)
          plot_data_bar << dp_values
        end
      end

    end

    [plot_data_bar, dp]
  end

  # get data for radar chart
  def get_plot_data_radar(analysis, datapoint_id = nil)
    # TODO: put the work on the database with projection queries (i.e. .only(:name, :age))
    # and this is just an ugly mapping, sorry all.
    # TODO: not sure why this is doubly nested array, but it's necessary for the radar plot code

    ovs = analysis.output_variables
    plot_data_radar = []

    if datapoint_id
      dp = analysis.data_points.find(datapoint_id)
    else
      if analysis.analysis_type == 'sequential_search'
        dp = analysis.data_points.all.order_by(:iteration.asc, :sample.asc).last
      else
        dp = analysis.data_points.all.order_by(:run_end_time.desc).first
      end
    end

    if dp['results']
      plot_data = []
      ovs.each do |ov|
        if ov['objective_function']
          dp_values = {}
          dp_values['axis'] = ov['name']
          if ov['scaling_factor']
            dp_values['value'] = (dp['results'][ov['name']].to_f - ov['objective_function_target'].to_f).abs / (ov['objective_function_target'].to_f)
          else
            dp_values['value'] = (dp['results'][ov['name']].to_f - ov['objective_function_target'].to_f).abs / (ov['objective_function_target'].to_f)
          end
          plot_data << dp_values
        end
      end
    end
    plot_data_radar << plot_data

    [plot_data_radar, dp]
  end

  # Simple method that takes in the analysis (to get the datapoints) and the variable map hash to construct
  # a useful JSON for plotting (and exporting to CSV/R-dataframe)
  # The results is the same as the variables hash which defines which results to export.  If nil it will only
  # export the results that in the output_variables hash
  def get_plot_data(analysis, variables, results = nil)
    plot_data = []
    if @analysis.analysis_type == 'sequential_search'
      dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
      dps = dps.rotate(1) # put the starting point on top
    else
      dps = @analysis.data_points.all
    end

    # load in the output variables that are requested (including objective functions)
    ovs = get_plot_variables(@analysis)

    dps.each do |dp|
      # the datapoint is considered complete if it has results set
      if dp.results
        dp_values = {}

        dp_values['data_point_uuid'] = data_point_path(dp.id)

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
            dp_values[ov] = dp['results'][ov] if dp['results'][ov]
          end
        end

        plot_data << dp_values
      end
    end

    plot_data
  end

  def get_plot_data_v2(analysis)
    # Get the mappings of the variables that were used - use the as_json only to hide the null default fields that show
    # up from the database only operator
    variables = nil
    plot_data = nil

    var_fields = [:_id, :perturbable, :display_name, :name, :units, :value_type, :data_type]
    # makes an array of hashes
    variables = Variable.variables(analysis).only(var_fields).as_json(:only => var_fields)
    variables += Variable.pivots(analysis).only(var_fields).as_json(:only => var_fields)
    variables.sort_by! { |v| v['name'] }

    # Create a map from the _id to the variables machine name
    variable_name_map = Hash[variables.map { |v| [v['_id'], v['name']] }]


    # flatten all the visualization variables to a queryable syntax
    visualizes = Variable.visualizes(analysis).only(var_fields).as_json(:only => var_fields)
    visualize_map = visualizes.map { |v| "results.#{v['name']}" }

    # initialize the plot fields that will need to be reported
    plot_fields = [:set_variable_values, :name, :_id] + visualize_map

    # Can't call the as_json(:only) method on this probably because of the nested results hash
    plot_data = analysis.data_points.where(status: 'completed').order_by(:created_at.asc).only(plot_fields).as_json

    # Flatten the results hash to the dot notation syntax
    plot_data.each do |pd|
      pd['results'] = hash_to_dot_notation(pd['results'])

      # For now, hack the set_variable_values values into the results! yes, this is a hack until we have
      # the datapoint actaully put it in the results
      #   First get the machine name for each variable using the variable_name_map
      variable_values = Hash[pd['set_variable_values'].map { |k, v| [variable_name_map[k], v] }]

      #   Second sort the values (VERY IMPORTANT)
      variable_values = Hash[variable_values.sort_by { |k, _| k }]

      # merge the variable values into the results hash
      pd['results'].merge!(variable_values)

      # now remove the set_variable_values section
      pd.delete('set_variable_values')

      # and then remove any other null field
      pd.delete_if { |k, v| v.nil? && plot_fields.exclude?(k) }

      # now flatten completely
      pd.merge!(pd.delete('results'))

      # copy _id to data_point_uuid for backwards compatibility
      pd['data_point_uuid'] = "/data_points/#{pd['_id']}"
    end

    # TODO: how to handle to sorting by iteration?
    # if @analysis.analysis_type == 'sequential_search'
    #   dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
    #   dps = dps.rotate(1) # put the starting point on top
    # else
    #   dps = @analysis.data_points.all
    # end

    [(variables + visualizes).uniq, plot_data]

  end

  def write_and_send_csv(analysis)
    require 'csv'

    # get variables from the variables object now instead of using the "superset_of_input_variables"
    variables, data = get_plot_data_v2(analysis)

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

    send_data csv_string, filename: filename, type: 'text/csv; charset=iso-8859-1; header=present', disposition: 'attachment'
  end

  def write_and_send_rdata(analysis)
    # get variables from the variables object now instead of using the "superset_of_input_variables"
    variables, data = get_plot_data_v2(analysis)

    # need to convert array of hash to hash of arrays
    # [{a: 1, b: 2}, {a: 3, b: 4}] to {a: [1,2], b: [3,4]}
    out_hash = data.each_with_object(Hash.new([])) do |h1, h|
      h1.each { |k, v| h[k] = h[k] + [v] }
    end

    download_filename = "#{analysis.name}_results.RData"
    data_frame_name = "results"
    Rails.logger.info("Data frame name will be #{data_frame_name}")

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

    if File.exist?(tmp_filename)
      send_data File.open(tmp_filename).read, filename: download_filename, type: 'application/rdata; header=present', disposition: 'attachment'
    else
      fail 'could not create R dataframe'
    end
  end
end
