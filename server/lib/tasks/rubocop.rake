namespace :rubocop do
  unless Rails.env == 'production'
    require 'rubocop/rake_task'

    desc 'Run Rubocop on the lib directory'
    RuboCop::RakeTask.new(:run) do |task|
      task.options = ['--no-color', '--out=../reports/rubocop/rubocop-results.xml', '--rails']
      task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
      task.requires = ['rubocop/formatter/checkstyle_formatter']
      # don't abort rake on failure
      task.fail_on_error = false
    end
  end
end