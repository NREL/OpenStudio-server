require "bundler"
Bundler.setup

require "rake"
require "git"
require "logger"
require "rspec/core/rake_task"
require 'colored'

# To release new version, increment the value in the ./server/lib/version file
require_relative "server/lib/version"

# todo: enable a second part of this that waits for testing of the amis before this is formally released
# VERSION_APPEND = Openstudioserver::VERSION_EXT
OPENSTUDIO_SERVER_VERSION = OpenstudioServer::VERSION + OpenstudioServer::VERSION_EXT
AMI_BUILD_BRANCH = "ami-build"

desc "build and release the server (via AMIs) using jenkins"
task :release do
  # verify that you are on master
  g = Git.open(File.dirname(__FILE__), :log => Logger.new("release.log"))

  raise "Must release from master branch" if g.current_branch != "master"

  if g.status.changed.size > 0 || g.status.added.size > 0 || g.status.deleted.size > 0
    s = "\n Changed: #{g.status.changed.size}\n Added: #{g.status.added.size}\n Deleted: #{g.status.deleted.size}"
    puts "#{s}\n There are uncommitted changes on the branch.  Please commit before proceeding.\n".red
    exit 0
  end

  # check you file again what is on remote
  h = g.diff('master', 'origin/master').stats

  if h[:total][:files] > 0
    puts "\nLocal branch has not been pushed to origin.  Please push before proceeding.\n".red
    exit 0
  end

  # do a git pull to make sure that we are up-to-date with tags
  g.pull

  # check if the current tag already existing
  ts = g.tags
  if ts.find { |t| t.name == OPENSTUDIO_SERVER_VERSION }
    puts "\nVersion already tagged. Please increment your version.  Current version is #{OPENSTUDIO_SERVER_VERSION}.\n".red
    exit 0
  end

  # add the new tag
  g.add_tag(OPENSTUDIO_SERVER_VERSION)

  # push the tags
  g.push("origin", "master", true)

  # push the code to the BUILD BRANCH
  g.checkout(AMI_BUILD_BRANCH)
  g.pull
  g.merge("origin/master")
  g.push("origin", AMI_BUILD_BRANCH)
  g.checkout("master")

  puts "\nSuccessfully create tag and pushed repo to server\n".green
end

RSpec::Core::RakeTask.new("spec") do |_spec|
  pwd = Dir.pwd
  # Dir.chdir("./server")
  # `bundle exec rspec`
end

require 'rubocop/rake_task'
desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  # only show the files with failures
  task.options = ['--no-color', '--out=rubocop-results.xml']
  task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  task.requires = ['rubocop/formatter/checkstyle_formatter']
  # don't abort rake on failure
  task.fail_on_error = false
end

task :default => :spec
