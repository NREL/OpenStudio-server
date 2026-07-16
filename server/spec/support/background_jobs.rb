# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# spec/support/background_jobs.rb
module BackgroundJobs
  # Destroy all projects with background jobs forced inline.
  #
  # Analysis#before_destroy enqueues DjJobs::DeleteAnalysis, an rm_rf of the
  # analysis directory. Cleanup hooks like before(:all)/after(:all) run outside
  # the foreground around-wrapper, so a plain Project.destroy_all there enqueues
  # that job for the web-background container to run LATER - and because the
  # spec formulations/factories reuse a fixed analysis uuid, the deferred rm_rf
  # can delete the shared analysis directory out from under whichever spec is
  # running by then. Force the deletion inline so cleanup finishes before the
  # hook returns.
  def destroy_projects_inline
    delay_jobs = Delayed::Worker.delay_jobs
    inline = Resque.inline
    Delayed::Worker.delay_jobs = false
    Resque.inline = true
    Project.destroy_all
  ensure
    Delayed::Worker.delay_jobs = delay_jobs
    Resque.inline = inline
  end

  def run_background_jobs_immediately
    if Rails.application.config.x.job_manager == :delayed_job
      delay_jobs = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
      yield
      Delayed::Worker.delay_jobs = delay_jobs
    elsif Rails.application.config.x.job_manager == :resque
      inline = Resque.inline
      Resque.inline = true
      yield
      Resque.inline = inline
    end
  end
end
