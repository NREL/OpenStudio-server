class VariablesController < ApplicationController
  # GET /variables
  # GET /variables.json
  def index
    @variables = Variable.where(analysis_id: params[:analysis_id], perturbable: true).order_by(name: 1)
    @outputs = Variable.where(analysis_id: params[:analysis_id], output: true).order_by(name: 1)
    @pivots = Variable.where(analysis_id: params[:analysis_id], pivot: true).order_by(name: 1)
    @others = Variable.where(analysis_id: params[:analysis_id], pivot: false, perturbable: false, output: false).order_by(name: 1)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: Variable.get_variable_data_v2(params[:analysis_id]) }
    end
  end

  # GET /variables/1
  # GET /variables/1.json
  def show
    @variable = Variable.find(params[:id])

    # get all the datapoints that have this variable in the set_variable_values
    @dps = DataPoint.exists("set_variable_values.#{@variable.id}" => true)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @variable }
    end
  end

  # GET /variables/new
  # GET /variables/new.json
  def new
    @variable = Variable.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @variable }
    end
  end

  # GET /variables/1/edit
  def edit
    @variable = Variable.find(params[:id])
  end

  # POST /variables
  # POST /variables.json
  def create
    @variable = Variable.new(params[:variable])

    respond_to do |format|
      if @variable.save
        format.html { redirect_to @variable, notice: 'Variable was successfully created.' }
        format.json { render json: @variable, status: :created, location: @variable }
      else
        format.html { render action: 'new' }
        format.json { render json: @variable.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /variables/1
  # PUT /variables/1.json
  def update
    @variable = Variable.find(params[:id])

    respond_to do |format|
      if @variable.update_attributes(params[:variable])
        format.html { redirect_to @variable, notice: 'Variable was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @variable.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /variables/1
  # DELETE /variables/1.json
  def destroy
    @variable = Variable.find(params[:id])
    @variable.destroy

    respond_to do |format|
      format.html { redirect_to variables_url }
      format.json { head :no_content }
    end
  end

  def download_variables
    analysis = Analysis.find(params[:analysis_id])

    respond_to do |format|
      format.csv do
        write_and_send_input_variables_csv(analysis)
        # redirect_to @analysis, notice: 'CSV not yet supported for downloading variables'
        # write_and_send_csv(@analysis)
      end
      format.rdata do
        write_and_send_input_variables_rdata(analysis)
      end
    end
  end

  # Bulk modify form
  def modify
    @variables = Variable.where(analysis_id: params[:analysis_id]).order_by(name: 1)

    if request.post?
      # TODO: sanitize params
      @variables.each do |var|
        if params[:visualize_ids].include? var.id
          var.visualize = true
        else
          var.visualize = false
        end
        if params[:export_ids].include? var.id
          var.export = true
        else
          var.export = false
        end
        var.save!
      end
    end
  end

  # GET metadata
  # DenCity view
  def metadata
    @variables = Variable.where(:metadata_id.ne => '', :metadata_id.ne => nil).order_by(name: 1)
  end

  def download_metadata
    respond_to do |format|
      format.csv do
        write_and_send_metadata_csv
      end
    end
  end

  protected

  def write_and_send_metadata_csv
    require 'csv'
    variables = Variable.where(:metadata_id.ne => '', :metadata_id.ne => nil)
    filename =  'dencity_metadata.csv'
    csv_string = CSV.generate do |csv|
      csv << %w(name display_name description units datatype user_defined)
      variables.each do |v|
        csv << [v.metadata_id, v.display_name, '', v.units, v.data_type, false]
      end
    end

    send_data csv_string, filename: filename, type: 'text/csv; charset=iso-8859-1; header=present', disposition: 'attachment'
  end

  def write_and_send_input_variables_csv(analysis)
    require 'csv'
    variables = Variable.get_variable_data_v2(analysis)

    filename = "#{analysis.name}_metadata.csv"
    csv_string = CSV.generate do |csv|
      icnt = 0
      variables.each do |dp|
        icnt += 1
        # Write out the header if this is the first datapoint
        csv << dp.keys if icnt == 1
        csv << dp.values
      end
    end

    send_data csv_string, filename: filename, type: 'text/csv; charset=iso-8859-1; header=present', disposition: 'attachment'
  end

  def write_and_send_input_variables_rdata(analysis)
    variables = Variable.get_variable_data_v2(analysis)

    # need to convert array of hash to hash of arrays
    # [{a: 1, b: 2}, {a: 3, b: 4}] to {a: [1,2], b: [3,4]}
    out_hash = variables.each_with_object(Hash.new([])) do |h1, h|
      h1.each { |k, v| h[k] = h[k] + [v] }
    end

    logger.info out_hash

    download_filename = "#{analysis.name}_metadata.RData"
    data_frame_name = 'metadata'

    Rails.logger.info("outhash is #{out_hash}")

    r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                APP_CONFIG['rserve_port'])
    r.command(data_frame_name.to_sym => out_hash.to_dataframe) do
      %{
            temp <- tempfile('rdata', tmpdir="/tmp")
            save('#{data_frame_name}', file = temp)
            Sys.chmod(temp, mode = "0777", use_umask = TRUE)
         }
    end
    tmp_filename = r.converse('temp')

    if File.exist?(tmp_filename)
      send_data File.open(tmp_filename).read, filename: download_filename, type: 'application/rdata; header=present', disposition: 'attachment'
    else
      raise 'could not create R dataframe'
    end

    # Have R delete the file since it will have permissions to delete the file.
    Rails.logger.info "Temp filename is #{tmp_filename}"
    r_command = "file.remove('#{tmp_filename}')"
    Rails.logger.info "R command is #{r_command}"
    if File.exist? tmp_filename
      r.converse(r_command)
    end
  end
end
