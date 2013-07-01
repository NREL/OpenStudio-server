class AlgorithmsController < ApplicationController
  # GET /algorithms
  # GET /algorithms.json
  def index
    @algorithms = Algorithm.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @algorithms }
    end
  end

  # GET /algorithms/1
  # GET /algorithms/1.json
  def show
    @algorithm = Algorithm.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @algorithm }
    end
  end

  # GET /algorithms/new
  # GET /algorithms/new.json
  def new
    @algorithm = Algorithm.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @algorithm }
    end
  end

  # GET /algorithms/1/edit
  def edit
    @algorithm = Algorithm.find(params[:id])
  end

  # POST /algorithms
  # POST /algorithms.json
  def create
    @algorithm = Algorithm.new(params[:algorithm])

    respond_to do |format|
      if @algorithm.save
        format.html { redirect_to @algorithm, notice: 'Algorithm was successfully created.' }
        format.json { render json: @algorithm, status: :created, location: @algorithm }
      else
        format.html { render action: "new" }
        format.json { render json: @algorithm.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /algorithms/1
  # PUT /algorithms/1.json
  def update
    @algorithm = Algorithm.find(params[:id])

    respond_to do |format|
      if @algorithm.update_attributes(params[:algorithm])
        format.html { redirect_to @algorithm, notice: 'Algorithm was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @algorithm.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /algorithms/1
  # DELETE /algorithms/1.json
  def destroy
    @algorithm = Algorithm.find(params[:id])
    @algorithm.destroy

    respond_to do |format|
      format.html { redirect_to algorithms_url }
      format.json { head :no_content }
    end
  end
end
