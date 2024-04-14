# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class PagesController < ApplicationController
  # static page
  def about; end

  # status page
  def status
    @awake = Status.first
    @awake_delta = @awake ? ((Time.now - @awake.awake) / 60).round(2) : nil
    @server = ComputeNode.where(node_type: 'server').first
    @workers = ComputeNode.where(node_type: 'worker')

    @file_systems = []

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
    @analyses = Analysis.all.order_by(:updated_at.asc)
    failed_runs = DataPoint.where(status_message: 'datapoint failure').count
    total_runs = DataPoint.all.count
    completed_cnt = DataPoint.where(status: 'completed').count

    if failed_runs.nonzero? && total_runs.nonzero?
      @failed_perc = (failed_runs.to_f / total_runs.to_f * 100).round(0)
    else
      @failed_perc = 0
    end
    if completed_cnt.nonzero? && total_runs.nonzero?
      @completed_perc = (completed_cnt.to_f / total_runs.to_f * 100).round(0)
    else
      @completed_perc = 0
    end

    # 2 analyses can be started at a time. show the one that was updated first
    #@current = @analyses.first
    # Select the first analysis that has any job with 'started' status
    #candidates = Analysis.all.order_by(:updated_at.asc)
    
    # Finding the current analysis
    #candidates = Analysis.includes(:jobs).order_by(:updated_at.asc)
    @current = @analyses.detect { |analysis| analysis.jobs.any? { |job| job.status == 'started' } }
    # If no 'started' analysis is currently running, optionally set @current to the most recently updated analysis
    @current ||= @analyses.first
    
    aggregated_results = nil
    unless @current.nil?
      # aggregate results of current analysis
      aggregated_results = DataPoint.collection.aggregate(
        [{ '$match' => { 'analysis_id' => @current.id } }, { '$group' => { '_id' => { 'analysis_id' => '$analysis_id', 'status' => '$status' }, count: { '$sum' => 1 } } }], :allow_disk_use => true
      )
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
