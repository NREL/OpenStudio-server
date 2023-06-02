#!/usr/bin/env ruby

ruby_regex = /^#.\*{79}.*#.\*{79}$/m
erb_regex = /^<%.*#.\*{79}.*#.\*{79}.%>$/m
js_regex = /^\/\* @preserve.*Copyright.*#.\*\//m

ruby_header_text = <<EOT
# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************
EOT
ruby_header_text.strip!

erb_header_text = <<EOT
<%
  # *******************************************************************************
  # OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
  # See also https://openstudio.net/license
  # *******************************************************************************
%>
EOT
erb_header_text.strip!

js_header_text = <<EOT
/* @preserve
 * OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC. reserved.
 * See also https://openstudio.net/license
*/
EOT
js_header_text.strip!

paths = [
    { glob: 'bin/resources/**/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/controllers/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/helpers/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/lib/analysis_library/**/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/lib/openstudio_server/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/mailers/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/models/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/workers/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/app/jobs/resque_jobs/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/config/environments/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/config/initializers/delayed_job_config.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/config/initializers/default_config.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/config/initializers/redis.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/config/initializers/ruby_path.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'docker/R/*.R', license: ruby_header_text, regex: ruby_regex },
    { glob: 'docker/R/lib/*.R', license: ruby_header_text, regex: ruby_regex },
    { glob: 'docker/R/lib/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/lib/tasks/**/*.rake', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/factories/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/features/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/files/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/models/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/requests/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/support/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'server/spec/*.rb', license: ruby_header_text, regex: ruby_regex },
    { glob: 'spec/**/*.rb', license: ruby_header_text, regex: ruby_regex },

    # single files
    { glob: 'bin/openstudio_meta', license: ruby_header_text, regex: ruby_regex },
    { glob: 'bin/resources/local/*', license: ruby_header_text, regex: ruby_regex },
    { glob: 'LICENSE', license: ruby_header_text, regex: ruby_regex },

    # erb
    { glob: 'server/app/views/**/*.html.erb', license: erb_header_text, regex: erb_regex },
    # js
    { glob: 'server/app/views/**/*.js.erb', license: js_header_text, regex: js_regex }
]

paths.each do |path|
  Dir[path[:glob]].each do |file|
    puts "Updating license in file #{file}"

    f = File.read(file)
    if f =~ path[:regex]
      puts '  License found -- updating'
      File.open(file, 'w') { |write| write << f.gsub(path[:regex], path[:license]) }
    else
      puts '  No license found -- adding'
      if f =~ /#!/
        puts '  CANNOT add license to file automatically, add it manually and it will update automatically in the future'
        next
      end
      File.open(file, 'w') { |write| write << f.insert(0, path[:license] + "\n\n") }
    end
  end
end
