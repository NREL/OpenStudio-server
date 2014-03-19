class PagesController < ApplicationController
  # static page
  def about

  end
  # main dashboard for the site
  def dashboard

    # data for dashboard header
    @projects = Project.all
    @analyses = Analysis.all
    failed_runs = DataPoint.where(:status_message => 'datapoint failure').count
    total_runs = DataPoint.all.count
    completed_cnt = DataPoint.where(:status => 'completed').count
    @failed_perc = (failed_runs.to_f/total_runs.to_f * 100).round(0)
    @completed_perc = (completed_cnt.to_f/total_runs.to_f * 100).round(0)

    # data for each analysis
    # can only aggregate over entire collection, so do that first then parse out results
    aggregated_results = DataPoint.collection.aggregate("$group" => { "_id" => {"analysis_id" => "$analysis_id", "status" => "$status"}, count: {"$sum" =>  1} })

    #TODO: this could probably be done more efficiently...
    @results = Array.new
    @js_results = Array.new
    @totals = Array.new

    @analyses.each do |run|
      row = {}
      row["id"] = run.id
      row["name"] = run.name
      row["project_name"] = run.project.name
      row["project_id"] = run.project.id
      row["created_at"] = run.created_at
      row["failed"] = run.data_points.where(:status_message => 'datapoint failure').count
      @results << row

      # for js
      cnt = 0
      js_res = Array.new
      aggregated_results.each do |res|
        logger.info("RESULT: #{res.inspect}")
        if res["_id"]["analysis_id"] == run.id
          # this is the format D3 wants the data in
          rec = {};
          rec["label"] = res["_id"]["status"]
          rec["value"] = res["count"]
          cnt += res["count"].to_i
          js_res << rec

        end
      end

      @js_results << js_res
      @totals << cnt

    end

    #@completed_runs = @analysis.data_points.where(:status => 'completed', :status_message => 'completed normal').count
    #@queued_runs = @analysis.data_points.where(:status => 'queued').count
    #@running_runs = @analysis.data_points.where(:status => 'running').count
    #@na_runs = @analysis.data_points.where(:status => 'na').count
    #@failed_runs = @analysis.data_points.where(:status_message => 'datapoint failure').count

    # count each type of simulation
    #@status_cnt = @analysis.data_points.collection.aggregate("$group" => { "_id" => "$status", count: {"$sum" =>  1} })
    #@failed_cnt = @analysis.data_points.where(:status_message => 'datapoint failure').count







  end
end
