require 'bundler'
Bundler.setup

require 'rake'
require 'git'
require 'logger'
require 'colored'

# To release new version, increment the value in the ./server/lib/openstudio_server/version.rb file
require_relative 'server/app/lib/openstudio_server/version'

# VERSION_APPEND = Openstudioserver::VERSION_EXT
OPENSTUDIO_SERVER_VERSION = OpenstudioServer::VERSION + OpenstudioServer::VERSION_EXT

desc 'build and release the server (via AMIs) using jenkins'
task :release do
  # verify that you are on master
  g = Git.open(File.dirname(__FILE__), log: Logger.new('release.log'))

  if !g.status.changed.empty? || !g.status.added.empty? || !g.status.deleted.empty?
    s = "\n Changed: #{g.status.changed.size}\n Added: #{g.status.added.size}\n Deleted: #{g.status.deleted.size}"
    puts "#{s}\n There are uncommitted changes on the branch.  Please commit before proceeding.\n".red
    exit 0
  end

  # check if the current tag already existing
  ts = g.tags
  if ts.find { |t| t.name == OPENSTUDIO_SERVER_VERSION }
    puts "\nVersion already tagged. Please increment your version.  Current version is #{OPENSTUDIO_SERVER_VERSION}.\n".red
    exit 0
  end

  # add the new tag
  g.add_tag(OPENSTUDIO_SERVER_VERSION)

  # push the tags
  g.push('origin', 'develop', true)

  puts "\nSuccessfully create tag and pushed repo to server\n".green
end
