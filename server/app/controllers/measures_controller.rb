#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
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
#*******************************************************************************

class MeasuresController < ApplicationController
  # GET /measures
  # GET /measures.json
  def index
    @measures = Measure.where(analysis_id: params[:analysis_id]).order_by(name: 1)

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
        format.html { render action: 'new' }
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
        format.html { render action: 'edit' }
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
