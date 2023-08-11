# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class ParetosController < ApplicationController
  # GET /paretos
  # GET /paretos.json
  def index
    @paretos = Pareto.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @paretos }
    end
  end

  # GET /paretos/1
  # GET /paretos/1.json
  def show
    @pareto = Pareto.find(params[:id])

    @analysis = @pareto.analysis
    @dps = @pareto.data_points.split(' ').join(',')

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @pareto }
    end
  end

  # GET /paretos/1/edit
  def edit
    @pareto = Pareto.find(params[:id])
  end

  # PUT /paretos/1
  # PUT /paretos/1.json
  def update
    @pareto = Pareto.find(params[:id])
    params = pareto_params

    respond_to do |format|
      if @pareto.update_attributes(params)
        format.html { redirect_to @pareto, notice: 'Pareto was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @pareto.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /paretos/1
  # DELETE /paretos/1.json
  def destroy
    @pareto = Pareto.find(params[:id])
    @pareto.destroy

    respond_to do |format|
      format.html { redirect_to paretos_url }
      format.json { head :no_content }
    end
  end

  private

  def pareto_params
    params.require(:pareto).permit!.to_h
  end
end
