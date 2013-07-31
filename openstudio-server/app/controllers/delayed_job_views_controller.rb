#module DelayedJobView
  class DelayedJobViewsController < ApplicationController
    respond_to :json, :html
    #layout 'dj_mon'

    #before_filter :authenticate
    #before_filter :set_api_version

    def index
      @dj = DelayedJobView::DelayedJobReport.all_reports
     # respond_with DelayedJobView::DelayedJobReport.all_reports
    end

    def all
      respond_with DelayedJobReport.all_reports
    end

    def failed
      respond_with DelayedJobReport.failed_reports
    end

    def active
      respond_with DelayedJobReport.active_reports
    end

    def queued
      respond_with DelayedJobReport.queued_reports
    end

    def dj_counts
      respond_with DelayedJobReport.dj_counts
    end

    def settings
      respond_with DelayedJobReport.settings
    end

    def retry
      DelayedJobView::Backend.retry params[:id]
      respond_to do |format|
        format.html { redirect_to root_url, :notice => "The job has been queued for a re-run" }
        format.json { head(:ok) }
      end
    end

    def destroy
      DelayedJobView::Backend.destroy params[:id]
      respond_to do |format|
        format.html { redirect_to root_url, :notice => "The job was deleted" }
        format.json { head(:ok) }
      end
    end

    protected

    #def authenticate
    #  authenticate_or_request_with_http_basic do |username, password|
    #    username == Rails.configuration.dj_mon.username &&
    #        password == Rails.configuration.dj_mon.password
    #  end
    #end

    #def set_api_version
    #  response.headers['DJ-Mon-Version'] = DjMon::VERSION
    #end

  end

#end
