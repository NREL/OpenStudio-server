# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

if defined?(RSpec)
  require 'rspec/core/rake_task'

  namespace :spec do
    RSpec::Core::RakeTask.new(:unit) do |t|
      puts 'Running tests'
      t.pattern = Dir['spec/*/**/*_spec.rb'].reject { |f| f['/api/v1'] || f['/integration'] }
      t.rspec_opts = ['--format', 'CI::Reporter::RSpec']
    end

    RSpec::Core::RakeTask.new(:integration) do |t|
      puts 'Running only the integration tests...'
      t.pattern = 'spec/integration/**/*_spec.rb'
      t.rspec_opts = ['--format', 'CI::Reporter::RSpec']
    end
  end
end
