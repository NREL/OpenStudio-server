class PagesController < ApplicationController
  def about
    # static page
  end

  def dashboard
    # main dashboard for the site

    @projects = Project.all
    @analyses = Analysis.all
    @failed_runs = DataPoint.where(:status_message => 'datapoint failure').count
    @total_runs = DataPoint.all.count
    @completed_cnt = DataPoint.where(:status => 'completed').count
    @failed_perc = (@failed_runs.to_f/@total_runs.to_f * 100).round(0)
    @completed_perc = (@completed_cnt.to_f/@total_runs.to_f * 100).round(0)

    @analysis = @analyses.first
    #@completed_runs = @analysis.data_points.where(:status => 'completed', :status_message => 'completed normal').count
    #@queued_runs = @analysis.data_points.where(:status => 'queued').count
    #@running_runs = @analysis.data_points.where(:status => 'running').count
    #@na_runs = @analysis.data_points.where(:status => 'na').count
    #@failed_runs = @analysis.data_points.where(:status_message => 'datapoint failure').count

    # count each type of simulation
    @status_cnt = @analysis.data_points.collection.aggregate("$group" => { "_id" => "$status", count: {"$sum" =>  1} })
    @failed_cnt = @analysis.data_points.where(:status_message => 'datapoint failure').count
  end
end
