namespace :run do
  desc 'run and example with R'
  task :example => :environment do
    project = Project.where(:name => "Example 1").first
    a = project.analyses.first

    a.start_r_and_run_sample
  end
end
