class MeasuresController < ApplicationController
  # GET /measures
  # GET /measures.json
  def index
    @measures = Measure.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @measures }
    end
  end

  # GET /measures/1
  # GET /measures/1.json
  def show
    @measure = Measure.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @measure }
    end
  end

  # GET /measures/new
  # GET /measures/new.json
  def new
    @measure = Measure.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @measure }
    end
  end

  # GET /measures/1/edit
  def edit
    @measure = Measure.find(params[:id])
  end

  # POST /measures
  # POST /measures.json
  def create
    @measure = Measure.new(params[:measure])

    respond_to do |format|
      if @measure.save
        format.html { redirect_to @measure, notice: 'Measure was successfully created.' }
        format.json { render json: @measure, status: :created, location: @measure }
      else
        format.html { render action: "new" }
        format.json { render json: @measure.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /measures/1
  # PUT /measures/1.json
  def update
    @measure = Measure.find(params[:id])

    respond_to do |format|
      if @measure.update_attributes(params[:measure])
        format.html { redirect_to @measure, notice: 'Measure was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @measure.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /measures/1
  # DELETE /measures/1.json
  def destroy
    @measure = Measure.find(params[:id])
    @measure.destroy

    respond_to do |format|
      format.html { redirect_to measures_url }
      format.json { head :no_content }
    end
  end
end
