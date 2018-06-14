# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require 'zip'

class AnalysesController < ApplicationController
  before_action :set_algorithm_results_path, only: [:show, :download_algorithm_results_zip]

  def set_algorithm_results_path
    @analysis = Analysis.find(params[:id])
    @algorithm_results_path = @analysis ? "#{APP_CONFIG['sim_root_path']}/analysis_#{@analysis.id}/downloads/" : ''
  end

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
      @all_page = @all_page == '' ? 1 : @all_page
      @completed_page = @status == 'completed' ? params[:page] : params[:completed_page]
      @completed_page = @completed_page == '' ? 1 : @completed_page
      @started_page = @status == 'started' ? params[:page] : params[:started_page]
      @started_page = @started_page == '' ? 1 : @started_page
      @queued_page = @status == 'queued' ? params[:page] : params[:queued_page]
      @queued_page = @queued_page == '' ? 1 : @queued_page
      @na_page = @status == 'na' ? params[:page] : params[:na_page]
      @na_page = @na_page == '' ? 1 : @na_page

      # if "view_all" param is set, use @all_sims_total instead of @all_sims (for ALL tab only)
      @view_all = 0
      if params[:view_all] && params[:view_all] == '1'
        @view_all = 1
        @all_sims = @analysis.search(params[:all_search], 'all', @all_page, @view_all)
      else
        @all_sims = @analysis.search(params[:all_search], 'all', @all_page, @view_all).page(@all_page).per(per_page)
      end

      # TODO: this is going to be slow because it returns the entire datapoint for each of these queries
      @completed_sims = @analysis.search(params[:completed_search], 'completed', @completed_page, @view_all).page(@completed_page).per(per_page)
      @started_sims = @analysis.search(params[:started_search], 'started', @started_page, @view_all).page(@started_page).per(per_page)
      @queued_sims = @analysis.search(params[:queued_search], 'queued', @queued_page, @view_all).page(@queued_page).per(per_page)
      @na_sims = @analysis.search(params[:na_search], 'na', @na_page, @view_all).page(@na_page).per(per_page)

      # Is this needed?
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

    logger.info("All: #{@all_sims}, Completed: #{@completed_sims}, Started: #{@started_sims}, Queued: #{@queued_sims}, N/A: #{@na_sims}")

    # TODO: find out if there are algorithm specific files to download
    @algorithm_results = false
    if Dir.exist?(@algorithm_results_path) && !Dir.glob(@algorithm_results_path + '*').empty?
      @algorithm_results = true
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
    params = analysis_params
    params[:project_id] = project_id

    @analysis = Analysis.new(params)
    @analysis.save!  # Make sure to save it before processing it further. Rails 5 upgrade issue.

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
    @analysis_type = params[:analysis_type].nil? ? 'batch_run' : params[:analysis_type]

    # params is now an object. Call to_h to get all the permitted parameters, and in this case, all of the params.
    options = params.permit!.to_h
    options[:run_data_point_filename] = params[:run_data_point_filename] if params[:run_data_point_filename]

    logger.info("After parsing JSON arguments and default values, analysis will run with the following options #{options}")

    if params[:analysis_action] == 'start'
      no_delay = params[:without_delay].to_s == 'true' ? true : false
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

  # version this in order to allow for analyses/status.json to return all the analyses with the status
  # @param :id [String] The ID of the specific analysis to get the status
  # @param :jobs [String] Constraint on the datapoint completion (e.g. started, queued, completed)
  # @param :version [String] Data are returned in an array in version 2. Defaults to version undefined/1
  def status
    analysis_only_fields = [:status, :analysis_type, :jobs, :run_flag, :exit_on_guideline_14]
    data_point_only_fields = [:status, :analysis_type, :analysis_id, :status_message, :name]

    job_statuses = params[:jobs] ? [params[:jobs]] : DataPoint.status_states
    # analysis_states = params[:state] ? [params[:state]] : Analyses.status_states

    logger.info 'Version 2 of analyses/status'
    @analyses = params[:id] ? Analysis.where(id: params[:id]).only(analysis_only_fields) : Analysis.all.only(analysis_only_fields)

    logger.info "there are #{@analyses.size} analyses"

    respond_to do |format|
      format.json do
        data = @analyses.map do |a|
          {
            _id: a.id,
            id: a.id,
            status: a.status,
            analysis_type: a.analysis_type,
            run_flag: a.run_flag,
            exit_on_guideline_14: a.exit_on_guideline_14,
            total_datapoints: a.data_points.where(:status.in => job_statuses).only(:id).count,
            jobs: a.jobs.order_by(:index.asc).map do |j|
                    {
                      index: j.index,
                      analysis_type: j.analysis_type,
                      status: j.status,
                      status_message: j.status_message
                    }
                  end,
            data_points: a.data_points.where(:status.in => job_statuses).only(data_point_only_fields).map do |dp|
                           {
                             _id: dp.id,
                             id: dp.id,
                             name: dp.name,
                             analysis_id: dp.analysis_id,
                             status: dp.status,
                             status_message: dp.status_message
                           }
                         end
          }
        end

        if data.size == 1
          render json: {
            analysis: data.first
          }
        else
          render json: {
            analyses: data
          }
        end
      end
    end
  end

  # GET /analyses/1/download_result_file
  def download_result_file
    @analysis = Analysis.find(params[:id])

    file = @analysis.result_files.where(attachment_file_name: params[:filename]).first
    if file && file.attachment && File.exist?(file.attachment.path)
      file_data = File.read(file.attachment.path)
      disposition = ['application/json', 'text/plain', 'text/html'].include?(file.attachment.content_type) ? 'inline' : 'attachment'
      send_data file_data, filename: File.basename(file.attachment.original_filename), type: file.attachment.content_type, disposition: disposition
    else
      respond_to do |format|
        format.json { render json: { status: 'error', error_message: 'could not find result file' }, status: :unprocessable_entity }
        format.html { redirect_to @analysis, notice: "Result file '#{params[:filename]}' does not exist. It probably was deleted from the file system." }
      end
    end
  end

  # GET /analyses/1/download_result_file
  def download_seed_zip
    @analysis = Analysis.find(params[:id])

    file = @analysis.seed_zip
    if file && File.exist?(file.path)
      file_data = File.read(file.path)
      send_data file_data, filename: File.basename(file.original_filename), type: file.content_type, disposition: 'attachment'
    else
      respond_to do |format|
        format.json { render json: { status: 'error', error_message: 'could not find result file' }, status: :unprocessable_entity }
        format.html { redirect_to @analysis, notice: 'Seed zip does not exist. It probably was deleted from the file system.' }
      end
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

    @rserve_log = nil
    rserve_file = File.join(APP_CONFIG['os_server_project_path'], 'log', 'Rserve.log')
    if File.exist? rserve_file
      @rserve_log = File.read(rserve_file)
    end

    exclude_fields = [:_id, :user, :password]
    @server = ComputeNode.where(node_type: 'server').first.as_json(expect: exclude_fields)
    @workers = ComputeNode.where(node_type: 'worker').map { |n| n.as_json(except: exclude_fields) }

    respond_to do |format|
      format.html # debug_log.html.erb
      format.json { render json: log_message }
    end
  end

  def snow_log
    @analysis = Analysis.find(params[:id])

    @snow_log = nil
    snow_file = File.join(APP_CONFIG['os_server_project_path'], 'log', 'snow.log')
    if File.exist? snow_file
      @snow_log = File.read(snow_file)
    end

    respond_to do |format|
      format.html # snow_log.html.erb
      format.json { render json: log_message }
    end
  end

  # TODO: Check if we can delete this!
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

  # TODO: rename this def with underscore
  def plot_parallelcoordinates
    @analysis = Analysis.find(params[:id])
    @saved_paretos = @analysis.paretos
    @include_all = false

    # variables for chart
    @pareto_data_points = {}
    @pareto_names = []
    @paretos = []

    # variables represent the variables we want graphed
    @visualizes = get_plot_variables(@analysis)
    @variables = params[:variables] ? params[:variables] : @visualizes.map(&:name)
    # pareto_series represent the paretos to include in the chart
    @pareto_series = params[:paretos] ? params[:paretos] : []

    @pareto_series.each do |p|
      temp_pareto = Pareto.find(p)
      @paretos << temp_pareto
      @pareto_data_points[p] = temp_pareto.data_points
      @pareto_names << temp_pareto.name
    end

    # include all data?
    logger.info("all_data param: #{params[:all_data]}")
    if (!params[:all_data].nil? && params[:all_data]) == 'true' || @pareto_series.empty?
      @include_all = true
    end

    # figure out actions
    # if params[:commit] && params[:commit] == 'All Data'
    # don't do pareto

    # else
    # check for pareto id
    # if params[:pareto]
    # @pareto = Pareto.find(params[:pareto])
    # @pareto_data_points = @pareto.data_points
    # @pareto_name = @pareto.name
    # end

    # end

    respond_to do |format|
      format.html # plot_parallelcoordinates.html.erb
    end
  end

  # Interactive XY plot: choose x and y variables
  def plot_xy_interactive
    @analysis = Analysis.find(params[:id])
    @saved_paretos = @analysis.paretos

    @plotvars = get_plot_variables(@analysis)

    @pareto = false
    @pareto_data_points = []
    @pareto_saved = false
    @debug = false

    # variables represent the variables we want graphed. Nil == choose the first 2
    @variables = []
    if params[:variables].nil?
      @variables << @plotvars[0].name << @plotvars[1].name
    else
      @variables << if params[:variables][:x]
                      params[:variables][:x]
                    else
                      @plotvars[0].name
                    end
      @variables << if params[:variables][:y]
                      params[:variables][:y]
                    else
                      @plotvars[0].name
                    end
    end

    # load a pareto by id
    if params[:pareto]
      pareto = Pareto.find(params[:pareto])
      @pareto_data_points = pareto.data_points
      @variables = [pareto.x_var, pareto.y_var]
    end

    # calculate pareto or update chart?
    if params[:commit] && params[:commit] == 'Calculate Pareto Front'
      # set variable for view
      @pareto = true
      # keep these pts in a variable, but mainly for quick debug
      pareto_pts = calculate_pareto(@variables)

      # this is what you actually need for the chart and to save a pareto
      @pareto_data_points = pareto_pts.map { |p| p['_id'] }
      # logger.info("DATAPOINTS ARRAY: #{@pareto_datapoints}")
    end

    # save pareto front?
    if params[:commit] && params[:commit] == 'Save Pareto Front'

      @pareto = true
      @pareto_data_points = params[:data_points]

      # save
      @new_pareto = Pareto.new
      @new_pareto.analysis = @analysis
      @new_pareto.x_var = params[:x_var]
      @new_pareto.y_var = params[:y_var]
      @new_pareto.name = params[:name]
      @new_pareto.data_points = params[:data_points]
      if @new_pareto.save
        logger.info('--pareto is saved--')
        @pareto_saved = true
        flash[:notice] = 'Pareto saved!'
      else
        flash[:error] = "The pareto front could not be saved: #{@new_pareto.errors.full_messages}"
      end
    end

    respond_to do |format|
      format.html # plot_xy.html.erb
    end
  end

  # Calculate Pareto
  def calculate_pareto(variables)
    # get data: reuse existing function
    vars, data = get_analysis_data(@analysis)
    # sort by x,y
    sorted_data = data.sort_by { |h| [h[variables[0]], h[variables[1]]] }

    # calculate Y cumulative minimum
    min_val = 1_000_000_000
    cum_min_arr = []
    sorted_data.each do |d|
      min_val = [min_val, d[variables[1]].to_f].min
      cum_min_arr << min_val
    end

    # calculate indexes of the unique entries, not the unique entries themselves
    no_dup_indexes = []
    cum_min_arr.each_with_index do |n, i|
      if i.zero?
        no_dup_indexes << i
      else
        if n != cum_min_arr[i - 1]
          no_dup_indexes << i
        end
      end
    end

    # DEBUG
    # logger.info("Unique Pareto Indexes: #{no_dup_indexes.inspect}")

    # pick final points & return
    pareto_points = []
    no_dup_indexes.each do |i|
      pareto_points << sorted_data[i]
    end
    pareto_points
  end

  def download_selected_datapoints
    @analysis = Analysis.find(params[:id])
    logger.info("DPS: #{params[:dps]}")
    if params[:dps]
      # get datapoints (make array)
      @datapoint_ids = params[:dps].split(',')
    end
    # TODO: what do you actually want returned here?
    write_and_send_rdata(@analysis, @datapoint_ids)
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
    @datapoint = if params[:datapoint_id]
                   DataPoint.find(params[:datapoint_id])
                 else

                   @datapoint = if @analysis.analysis_type == 'sequential_search'
                                  @analysis.data_points.all.order_by(:iteration.asc, :sample.asc).last
                                else
                                  @analysis.data_points.all.order_by(:run_end_time.desc).first
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
    @variables, @data = get_analysis_data(@analysis, datapoint_id, true, options)

    logger.info 'sending analysis data to view'
    respond_to do |format|
      format.json { render json: { variables: @variables, data: @data } }
      format.html # analysis_data.html.erb
    end
  end

  def page_data
    @analysis = Analysis.find(params[:id])

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

  # Download the analysis.zip file for the worker nodes
  def download_analysis_zip
    @analysis = Analysis.find(params[:id])

    unless @analysis.seed_zip.nil?
      send_data File.open(@analysis.seed_zip.path, 'rb').read, filename: 'analysis.zip', type: @analysis.seed_zip.content_type, disposition: 'attachment'
    end
  end

  def download_algorithm_results_zip
    @analysis = Analysis.find(params[:id])

    zipfile_name = "algorithm_results_#{@analysis.id}.zip"
    temp_file = Tempfile.new(zipfile_name)

    if Dir.exist?(@algorithm_results_path)
      paths = Dir.glob(@algorithm_results_path + '*')
      begin
        # Initialize the temp file as a zip file
        Zip::OutputStream.open(temp_file) { |zos| }

        # Add files to the zip file as usual
        Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
          # Put files in here
          paths.each do |fi|
            logger.info(fi)
            # Two arguments:
            # - The name of the file as it will appear in the archive
            # - The original file, including the path to find it
            zip.add(File.basename(fi), fi)
          end
        end

        # Read the binary data from the file
        zip_data = File.read(temp_file.path)

        # Send the data to the browser as an attachment
        send_data(zip_data, type: 'application/zip', filename: zipfile_name, disposition: 'attachment')
      ensure
        # Close and delete the temp file
        temp_file.close
        temp_file.unlink
      end
    end
  end

  def dencity
    @analysis = Analysis.find(params[:id])

    if @analysis
      # reformat the data slightly to get a concise view of the data
      prov_fields = %w(uuid created_at name display_name description)

      a = @analysis.as_json
      a.each do |k, _v|
        logger.info k
      end
      @provenance = a.select { |key, _| prov_fields.include? key }

      @provenance['user_defined_id'] = @provenance.delete('uuid')
      @provenance['user_created_date'] = @provenance.delete('created_at')
      @provenance['analysis_types'] = @analysis.analysis_types

      @measure_metadata = []
      if @analysis['problem']
        if @analysis['problem']['algorithm']
          @provenance['analysis_information'] = @analysis['problem']['algorithm']
        end

        if @analysis['problem']['workflow']
          @analysis['problem']['workflow'].each do |wf|
            new_wfi = {}
            new_wfi['id'] = wf['measure_definition_uuid']
            new_wfi['version_id'] = wf['measure_definition_version_uuid']

            # Eventually all of this could be pulled directly from BCL
            new_wfi['name'] = wf['measure_definition_class_name']
            new_wfi['display_name'] = wf['measure_definition_display_name']
            new_wfi['type'] = wf['measure_type']
            new_wfi['modeler_description'] = wf['modeler_description']
            new_wfi['description'] = wf['description']

            new_wfi['arguments'] = []
            if wf['arguments']
              wf['arguments'].each do |arg|
                wfi_arg = {}
                wfi_arg['display_name'] = arg['display_name']
                wfi_arg['display_name_short'] = arg['display_name_short']
                wfi_arg['name'] = arg['name']
                wfi_arg['data_type'] = arg['value_type']
                wfi_arg['default_value'] = nil
                wfi_arg['description'] = ''
                wfi_arg['display_units'] = '' # should be haystack compatible unit strings
                wfi_arg['units'] = '' # should be haystack compatible unit strings

                new_wfi['arguments'] << wfi_arg
              end
            end

            if wf['variables']
              wf['variables'].each do |arg|
                wfi_var = {}
                wfi_var['display_name'] = arg['argument']['display_name']
                wfi_var['display_name_short'] = arg['argument']['display_name_short']
                wfi_var['name'] = arg['argument']['name']
                wfi_var['default_value'] = nil
                wfi_var['data_type'] = arg['argument']['value_type']
                wfi_var['description'] = ''
                wfi_var['display_units'] = arg['units']
                wfi_var['units'] = '' # should be haystack compatible unit strings

                new_wfi['arguments'] << wfi_var
              end
            end

            @measure_metadata << new_wfi
          end
        end
      end
    end

    respond_to do |format|
      # format.html # show.html.erb
      format.json { render partial: 'analyses/dencity', formats: [:json] }
    end
  end

  protected

  # Get data across analysis. If a datapoint_id is specified, will return only that point
  # options control the query of returned variables, and can contain: visualize, export, pivot, and perturbable toggles
  def get_analysis_data(analysis, datapoint_id = nil, only_completed_normal = true, options = {})
    # Get the mappings of the variables that were used - use the as_json only to hide the null default fields that show
    # up from the database only operator

    # require 'ruby-prof'
    # RubyProf.start
    start_time = Time.now
    variables = nil
    plot_data = nil

    var_fields = [:_id, :perturbable, :pivot, :visualize, :export, :output, :objective_function,
                  :objective_function_group, :objective_function_index, :objective_function_target,
                  :scaling_factor, :display_name, :display_name_short, :name, :units, :value_type, :data_type]

    # dynamic query, only add 'or' for option fields that are true
    or_qry = [{ perturbable: true }, { pivot: true }, { output: true }]
    options.each do |k, v|
      or_qry << { :"#{k}" => v } if v
    end
    variables = Variable.where(analysis_id: analysis, :name.nin => ['', nil]).or(or_qry)
                        .order_by([:pivot.desc, :perturbable.desc, :output.desc, :name.asc]).as_json(only: var_fields)

    # Create a map from the _id to the variables machine name
    variable_name_map = Hash[variables.map { |v| [v['_id'], v['name'].tr('.', '|')] }]
    # logger.info "Variable name map is #{variable_name_map}"

    # logger.info 'looking for datapoints'

    # This map/reduce method is much faster than trying to do all this munging via mongoid/json/hashes. The concept
    # below is to map the inputs/outputs to a flat hash.
    map = %{
      function() {
         key = this._id;
         new_data = {
                      name: this.name, run_start_time: this.run_start_time, run_end_time: this.run_end_time,
                      status: this.status, status_message: this.status_message
                    };

         // Retrieve all the results and map the variables to a.b
         var mrMap = #{variables.map { |v| v['name'].split('.') }.to_json};
         for (var i in mrMap){
           if (typeof this.results[mrMap[i][0]] !== 'undefined' && typeof this.results[mrMap[i][0]][mrMap[i][1]] !== 'undefined') {
             new_data[mrMap[i].join('|')] = this.results[mrMap[i][0]][mrMap[i][1]]
           }
         }

         // Set the variable names to a.b
         var variableMap = #{variable_name_map.reject { |_k, v| v.nil? }.to_json};
         for (var p in this.set_variable_values) {
            new_data[variableMap[p]] = this.set_variable_values[p];
         }

         new_data['data_point_uuid'] = "/data_points/" + this._id

         emit(key, new_data);
      }
    }

    reduce = %{
      function(key, values) {
        return values[0];
      }
    }

    finalize = %{
      function(key, value) {
        value['_id'] = key;
        db.datapoints_mr.insert(value);
      }
    }

    # Eventually use this where the timestamp is processed as part of the request to save time
    plot_data = if datapoint_id
                  if only_completed_normal
                    DataPoint.where(
                        analysis_id: analysis, status: 'completed', id: datapoint_id, status_message: 'completed normal'
                    )
                  else
                    DataPoint.where(analysis_id: analysis, id: datapoint_id)
                  end
                else
                  if only_completed_normal
                    DataPoint.where(analysis_id: analysis, status: 'completed', status_message: 'completed normal')
                        .order_by(:created_at.asc)
                  else
                    DataPoint.where(analysis_id: analysis).order_by(:created_at.asc)
                  end
                end

    logger.info "finished fixing up data: #{Time.now - start_time}"

    start_time = Time.now
    logger.info 'mapping variables'
    variables.map! { |v| { :"#{v['name']}".to_sym => v } }

    variables = variables.reduce({}, :merge)
    logger.info "finished mapping variables: #{Time.now - start_time}"

    start_time = Time.now
    logger.info 'Start map/reduce'
    # Remove all the old items first
    Mongoid.default_client.database.collection(:"datapoints_mr_#{analysis.id}").drop
    plot_data = plot_data.map_reduce(map, reduce).out(replace: "datapoints_mr_#{analysis.id}")
    # just call the first one so that is flushes the results to the database
    plot_data.first
    logger.info "Finished map/reduce: #{Time.now - start_time}"

    # Go query the map reduce results again. For some reason the results of the map/reduce is
    # limited to only the first 100 documents.
    start_time = Time.now
    logger.info 'Start as_json'
    plot_data = Mongoid.default_client.database.collection(:"datapoints_mr_#{analysis.id}").find.as_json
    logger.info "Finished as_json: #{Time.now - start_time}"

    start_time = Time.now
    logger.info 'Start collapse'
    plot_data.each_with_index do |pd, i|
      pd.merge!(pd.delete('value'))

      # Horrible hack right now until we decide how to handle variables with periods in the key
      #   The root of this issue is that Mongo 2.6 now strictly checks for periods in the hash and will
      #   throw an exception.  The map/reduce script above has to save the result of the map/reduce to the
      #   database because it is too large.  So the results have to be stored with pipes (|) temporary, then
      #   mapped back out.
      plot_data[i] = Hash[pd.map { |k, v| [k.tr('|', '.'), v] }]
    end
    logger.info "finished merge: #{Time.now - start_time}"

    # plot_data.merge(plot_data.delete('value'))

    [variables, plot_data]
  end

  # Get plot variables
  # Used by plot_parallelcoordinates
  def get_plot_variables(analysis)
    variables = Variable.where(analysis_id: analysis).or(perturbable: true).or(pivot: true).or(visualize: true).order_by(:name.asc)
  end

  def write_and_send_csv(analysis, datapoint_ids = nil)
    require 'csv'

    # get variables from the variables object now instead of using the "superset_of_input_variables"
    variables, data = get_analysis_data(analysis, datapoint_ids, false, export: true)
    static_fields = %w(name _id run_start_time run_end_time status status_message)

    logger.info variables
    filename = "#{analysis.name}.csv"
    csv_string = CSV.generate do |csv|
      csv << static_fields + variables.map { |_k, v| v['output'] ? v['name'] : v['name'] }
      data.each do |dp|
        # this is really slow right now because it is iterating over each piece of data because i can't guarentee the existence of all the values
        arr = []
        (static_fields + variables.map { |_k, v| v['output'] ? v['name'] : v['name'] }).each do |v|
          arr << if dp[v].nil?
                   nil
                 else
                   dp[v]
                 end
        end
        csv << arr
      end
    end

    send_data csv_string, filename: filename, type: 'text/csv; charset=iso-8859-1; header=present', disposition: 'attachment'
  end

  def write_and_send_rdata(analysis, datapoint_ids = nil)
    # get variables from the variables object now instead of using the "superset_of_input_variables"
    variables, data = get_analysis_data(analysis, datapoint_ids, false, export: true)

    static_fields = %w(name _id run_start_time run_end_time status status_message)
    names_of_vars = static_fields + variables.map { |_k, v| v['output'] ? v['name'] : v['name'] }

    # TODO: this is reeeally slow and needs to be addressed # finished conversion: 1764.665880011 ~ 13k points
    # need to convert array of hash to hash of arrays
    # [{a: 1, b: 2}, {a: 3, b: 4}] to {a: [1,2], b: [3,4]}
    start_time = Time.now
    logger.info 'starting conversion of data to column vectors'
    out_hash = data.each_with_object(Hash.new([])) do |ex_hash, h|
      names_of_vars.each do |v|
        add_this_value = ex_hash[v].nil? ? nil : ex_hash[v]
        h[v] = h[v] + [add_this_value]
      end
    end
    logger.info "finished conversion: #{Time.now - start_time}"

    # If the data are guaranteed to exist in the same column structure for each datapoint AND the
    # length of each column is the same (especially no nils), then you can use the method below
    # out_hash = data.each_with_object(Hash.new([])) do |ex_hash, h|
    # ex_hash.each { |k, v| h[k] = h[k] + [v] }
    # end

    # out_hash.each_key do |k|
    #  #logger.info "Length is #{out_hash[k].size}"
    #  logger.info "#{k}  -   #{out_hash[k]}"
    # end

    download_filename = "#{analysis.name}_results.RData"
    data_frame_name = 'results'

    r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                APP_CONFIG['rserve_port'])

    start_time = Time.now
    logger.info 'starting creation of data frame'
    # TODO: check these permissions and make them less open
    r.command(data_frame_name.to_sym => out_hash.to_dataframe) do
      %{
            temp <- tempfile('rdata', tmpdir="/tmp")
            save('#{data_frame_name}', file = temp)
            Sys.chmod(temp, mode = "0777", use_umask = TRUE)
         }
    end
    tmp_filename = r.converse('temp')
    logger.info "finished data frame: #{Time.now - start_time}"

    if File.exist?(tmp_filename)
      send_data File.open(tmp_filename).read, filename: download_filename, type: 'application/rdata; header=present', disposition: 'attachment'
    else
      raise 'could not create R dataframe'
    end
  end

  private

  def analysis_params
    params.require(:analysis).permit!.to_h
  end
end
