namespace :delayed_job do
  desc 'Restart the delayed_job process'
  task restart: :environment do
    run "cd #{current_path}; RAILS_ENV=#{rails_env} script/delayed_job restart"
  end
end
