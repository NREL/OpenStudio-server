class PagesController < ApplicationController
  # static page
  def about
  end

  # main dashboard for the site
  def dashboard
    # data for dashboard header
    @projects = Project.all
    # sort works because the states are queued, started, completed, na. started is the last in the list...
    @analyses = Analysis.all.order_by(:status.desc, :start_time.desc)
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
          [{'$match' => {'analysis_id' => @current.id}},{'$group' => {'_id' => {'analysis_id' => '$analysis_id', 'status' => '$status'}, count: {'$sum' => 1}}}])
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
