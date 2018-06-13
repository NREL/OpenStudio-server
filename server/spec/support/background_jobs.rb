# spec/support/background_jobs.rb
module BackgroundJobs
  def run_background_jobs_immediately
    if Rails.application.config.job_manager == :delayed_job
      delay_jobs = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
      yield
      Delayed::Worker.delay_jobs = delay_jobs
    elsif Rails.application.config.job_manager == :resque
      inline = Resque.inline
      Resque.inline = true
      yield
      Resque.inline = inline
    end
  end
end