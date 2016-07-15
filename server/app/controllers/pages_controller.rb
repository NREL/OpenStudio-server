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

class PagesController < ApplicationController
  # static page
  def about
  end

  # status page
  def status
    @awake = Status.first
    @awake_delta = @awake ? ((Time.now - @awake.awake) / 60).round(2) : nil
    @server = ComputeNode.where(node_type: 'server').first
    @workers = ComputeNode.where(node_type: 'worker')

    @file_systems = []
    filesystems = Sys::Filesystem.mounts
    filesystems.each do |fs|
      f = Sys::Filesystem.stat(fs.mount_point)
      mb_percent = f.bytes_total == 0 ? 0 : ((f.bytes_used.to_f / f.bytes_total.to_f) * 100).round(2)

      @file_systems << {
        mount_point: fs.mount_point,
        percent_used: mb_percent,
        mb_used: f.bytes_used / 1E6,
        mb_free: f.bytes_free / 1E6,
        mb_total: f.bytes_total / 1E6
      }
    end

    # this would probably be better as an openstruct
    # find where the /mnt/ folder lives
    # TODO: make this cross-platform
    @mnt_fs = nil
    @mnt_fs = @file_systems.select { |f| f[:mount_point] =~ /\/mnt/ }
    @mnt_fs = @file_systems.select { |f| f[:mount_point] == '/' } if @mnt_fs.empty?

    respond_to do |format|
      format.html # status.html.erb
      format.json # status.json.jbuilder
    end
  end

  # main dashboard for the site
  def dashboard
    # data for dashboard header
    @projects = Project.all
    # sort works because the states are queued, started, completed, na. started is the last in the list...
    @analyses = Analysis.all.order_by(:updated_at.desc)
    failed_runs = DataPoint.where(status_message: 'datapoint failure').count
    total_runs = DataPoint.all.count
    completed_cnt = DataPoint.where(status: 'completed').count

    if failed_runs != 0 && total_runs != 0
      @failed_perc = (failed_runs.to_f / total_runs.to_f * 100).round(0)
    else
      @failed_perc = 0
    end
    if completed_cnt != 0 && total_runs != 0
      @completed_perc = (completed_cnt.to_f / total_runs.to_f * 100).round(0)
    else
      @completed_perc = 0
    end

    # currently running / last run analysis (only 1 can run at a time)
    @current = @analyses.first
    aggregated_results = nil
    unless @current.nil?
      # aggregate results of current analysis
      aggregated_results = DataPoint.collection.aggregate(
        [{ '$match' => { 'analysis_id' => @current.id } }, { '$group' => { '_id' => { 'analysis_id' => '$analysis_id', 'status' => '$status' }, count: { '$sum' => 1 } } }])
    end
    # for js
    cnt = 0
    @js_res = []
    @total = 0

    unless @current.nil?
      aggregated_results.each do |res|
        # this is the format D3 wants the data in
        rec = {}
        rec['label'] = res['_id']['status']
        rec['value'] = res['count']
        cnt += res['count'].to_i
        @js_res << rec
      end

      @total = cnt
    end
  end
end
