class SeedsController < ApplicationController
  # GET /seeds
  # GET /seeds.json
  def index
    @seeds = Seed.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @seeds }
    end
  end

  # GET /seeds/1
  # GET /seeds/1.json
  def show
    @seed = Seed.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @seed }
    end
  end

  # GET /seeds/new
  # GET /seeds/new.json
  def new
    @seed = Seed.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @seed }
    end
  end

  # GET /seeds/1/edit
  def edit
    @seed = Seed.find(params[:id])
  end

  # POST /seeds
  # POST /seeds.json
  def create
    @seed = Seed.new(params[:seed])

    respond_to do |format|
      if @seed.save
        format.html { redirect_to @seed, notice: 'Seed was successfully created.' }
        format.json { render json: @seed, status: :created, location: @seed }
      else
        format.html { render action: "new" }
        format.json { render json: @seed.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /seeds/1
  # PUT /seeds/1.json
  def update
    @seed = Seed.find(params[:id])

    respond_to do |format|
      if @seed.update_attributes(params[:seed])
        format.html { redirect_to @seed, notice: 'Seed was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @seed.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /seeds/1
  # DELETE /seeds/1.json
  def destroy
    @seed = Seed.find(params[:id])
    @seed.destroy

    respond_to do |format|
      format.html { redirect_to seeds_url }
      format.json { head :no_content }
    end
  end
end
