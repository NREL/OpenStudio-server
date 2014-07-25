require 'will_paginate/array'
require 'core_extensions'

class AnalysesController < ApplicationController
  # GET /analyses
  # GET /analyses.json
  def index
    if params[:project_id].nil?
      @analyses = Analysis.all.order_by(:start_time.asc)
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

      @has_obj_targets = @analysis.variables.where(:objective_function_target.ne => nil).count > 0 ? true : false

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

      @objective_functions = @analysis.variables.where(objective_function: true).order_by(:objective_function.asc, :sample.asc)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: { analysis: @analysis } }
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
      format.json do
        render json: {
          analysis: {
            status: @analysis.status,
            analysis_type: @analysis.analysis_type,
            jobs: @analysis.jobs.order_by(:index.asc)
          },
          data_points: dps.map { |k| { _id: k.id, status: k.status, final_message: k.status_message } } }
      end
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
      format.json { render json: { analysis: { status: @analysis.status }, data_points: dps.map { |k| { _id: k.id, status: k.status, download_status: k.download_status } } } }
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
    @server = ComputeNode.where(node_type: 'server').first.as_json(expect: exclude_fields)
    @workers = ComputeNode.where(node_type: 'worker').map { |n| n.as_json(except: exclude_fields) }

    respond_to do |format|
      format.html # debug_log.html.erb
      format.json { render json: log_message }
    end
  end

  def new_view
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      exclude_fields = [
        :problem
      ]
      include_fields = [
        :variables,
        :measures # => {:include => :variables}
      ]
      #  format.html # new.html.erb
      format.json { render json: { analysis: @analysis.as_json(except: exclude_fields, include: include_fields) } }
    end
  end

  # Parallel Coordinates plot
  def plot_parallelcoordinates
    @analysis = Analysis.find(params[:id])

    # variables represent the variables we want graphed. Nil = all
    @variables = params[:variables] ? params[:variables] : nil
    var_fields = [:id, :display_name, :name, :units]
    @visualizes = get_plot_variables(@analysis)

    respond_to do |format|
      format.html # plot_parallelcoordinates.html.erb
    end
  end

  # Interactive XY plot: choose x and y variables
  def plot_xy_interactive
    @analysis = Analysis.find(params[:id])

    @plotvars = get_plot_variables(@analysis)
    logger.info "PLOTVARS: #{@plotvars}"

    # variables represent the variables we want graphed. Nil == choose the first 2
    @variables = []
    if params[:variables].nil?
      @variables << @plotvars[0].name << @plotvars[1].name
    else
      if params[:variables][:x]
        @variables << params[:variables][:x]
      else
        @variables << @plotvars[0].name
      end
      if params[:variables][:y]
        @variables << params[:variables][:y]
      else
        @variables << @plotvars[0].name
      end
    end

    respond_to do |format|
      format.html # plot_xy.html.erb
    end
  end

  # Scatter plot
  def plot_scatter
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # plot_scatter.html.erb
    end
  end

  # Radar plot (single datapoint, must have objective functions)
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

  # Bar chart (single datapoint, must have objective functions)
  # "% error"-like, but negative when actual is less than target and positive when it is more than target
  def plot_bar
    @analysis = Analysis.find(params[:id])
    @datapoint = DataPoint.find(params[:datapoint_id])

    respond_to do |format|
      format.html # plot_bar.html.erb
    end
  end

  # This function provides all data (plot or export data, depending on what is specified) in
  # a JSON format that can be consumed by various users such as the bar plots, parallel plots, pairwise plots, etc.
  def analysis_data
    @analysis = Analysis.find(params[:id])
    datapoint_id = params[:datapoint_id] ? params[:datapoint_id] : nil
    # other variables that can be specified
    options = {}
    options['visualize'] = params[:visualize] == 'true' ? true : false
    options['export'] = params[:export] == 'true' ? true : false
    options['pivot'] = params[:pivot] == 'true' ? true : false
    options['perturbable'] = params[:perturbable] == 'true' ? true : false

    # get data
    @variables, @data = get_analysis_data(@analysis, datapoint_id, options)

    respond_to do |format|
      format.json { render json: { variables: @variables, data: @data } }
      format.html # analysis_data.html.erb
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

        render json: { analysis: @analysis.as_json(only: fields, include: :data_points) }
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

  protected

  # Get data across analysis. If a datapoint_id is specified, will return only that point
  # options control the query of returned variables, and can contain: visualize, export, pivot, and perturbable toggles
  def get_analysis_data(analysis, datapoint_id = nil, options = nil)
    # Get the mappings of the variables that were used - use the as_json only to hide the null default fields that show
    # up from the database only operator
    variables = nil
    plot_data = nil

    var_fields = [:_id, :perturbable, :pivot, :visualize, :export, :output, :objective_function,
                  :objective_function_group, :objective_function_index, :objective_function_target,
                  :scaling_factor, :display_name, :display_name_short, :name, :units, :value_type, :data_type]

    # dynamic query, only add 'or' for option fields that are true
    or_qry = []
    if options
      options.each do |k, v|
        if v
          # add to or
          or_item = {}
          or_item[k] = v
          or_qry << or_item
        end
      end
    end
    variables = Variable.where(analysis_id: analysis).or(or_qry).order_by(:name.asc).as_json(only: var_fields)

    # Create a map from the _id to the variables machine name
    variable_name_map = Hash[variables.map { |v| [v['_id'], v['name']] }]

    visualize_map = variables.map { |v| "results.#{v['name']}" }
    # initialize the plot fields that will need to be reported
    plot_fields = [:set_variable_values, :name, :_id, :run_start_time, :run_end_time] + visualize_map

    # Can't call the as_json(:only) method on this probably because of the nested results hash
    if datapoint_id
      plot_data = analysis.data_points.where(status: 'completed', status_message: 'completed normal', id: datapoint_id).order_by(:created_at.asc).only(plot_fields).as_json
    else
      plot_data = analysis.data_points.where(status: 'completed', status_message: 'completed normal').order_by(:created_at.asc).only(plot_fields).as_json
    end

    # Flatten the results hash to the dot notation syntax
    Rails.logger.info plot_data
    plot_data.each do |pd|
      unless pd['results'].empty?
        pd['results'] = hash_to_dot_notation(pd['results'])

        # For now, hack the set_variable_values values into the results! yes, this is a hack until we have
        # the datapoint actually put it in the results

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
        pd.merge!(pd.delete('results')) if pd

        # copy _id to data_point_uuid for backwards compatibility
        pd['data_point_uuid'] = "/data_points/#{pd['_id']}"
      end
    end

    # TODO: how to handle to sorting by iteration?
    # if @analysis.analysis_type == 'sequential_search'
    #   dps = @analysis.data_points.all.order_by(:iteration.asc, :sample.asc)
    #   dps = dps.rotate(1) # put the starting point on top
    # else
    #   dps = @analysis.data_points.all
    # end

    variables.map! { |v| { :"#{v['name']}".to_sym => v } }

    logger.info variables.class
    # logger.info .reduce({}, :merge)

    variables = variables.reduce({}, :merge)
    # variables.reduce(|v| {}, :merge)
    [variables, plot_data]
  end

  # Get plot variables
  # Used by plot_parallelcoordinates
  def get_plot_variables(analysis)
    variables = Variable.where(analysis_id: analysis).or(perturbable: true).or(pivot: true).or(visualize: true).order_by(:name.asc)
  end

  def write_and_send_csv(analysis)
    require 'csv'

    # get variables from the variables object now instead of using the "superset_of_input_variables"
    variables, data = get_analysis_data(analysis, nil, export: true)

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
    variables, data = get_analysis_data(analysis, nil, export: true)

    # need to convert array of hash to hash of arrays
    # [{a: 1, b: 2}, {a: 3, b: 4}] to {a: [1,2], b: [3,4]}
    out_hash = data.each_with_object(Hash.new([])) do |h1, h|
      h1.each { |k, v| h[k] = h[k] + [v] }
    end

    download_filename = "#{analysis.name}_results.RData"
    data_frame_name = 'results'
    Rails.logger.info("Data frame name will be #{data_frame_name}")

    # TODO: move this to a helper method of some sort under /lib/anlaysis/r/...
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
