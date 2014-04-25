class VariablesController < ApplicationController
  # GET /variables
  # GET /variables.json
  def index
    @variables = Variable.where(analysis_id: params[:analysis_id], perturbable: true).order_by(name: 1)
    @statics = Variable.where(analysis_id: params[:analysis_id], static: true).order_by(name: 1)
    @pivots = Variable.where(analysis_id: params[:analysis_id], pivot: true).order_by(name: 1)
    @others = Variable.where(analysis_id: params[:analysis_id], pivot: false, perturbable: false, static: false).order_by(name: 1)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @variables }
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
end
