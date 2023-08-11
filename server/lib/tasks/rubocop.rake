# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

namespace :rubocop do
  if Rails.env != 'production' && Rails.env != 'docker' && Rails.env != 'local'
    require 'rubocop/rake_task'

    desc 'Run Rubocop on the server directory'
    RuboCop::RakeTask.new(:run) do |task|
      task.options = ['--no-color', '--rails', '--out=../reports/rubocop/rubocop-results.xml', '--format', 'simple']
      task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
      task.requires = ['rubocop/formatter/checkstyle_formatter']
      # don't abort rake on failure
      task.fail_on_error = false
    end
  end
end
