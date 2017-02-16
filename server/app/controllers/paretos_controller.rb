# *******************************************************************************
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

    respond_to do |format|
      if @pareto.update_attributes(params[:pareto])
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
end
