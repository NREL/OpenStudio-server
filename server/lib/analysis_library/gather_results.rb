require 'git'
require 'uri'

def git_clean_rep(url,options)
  url = URI.parse(url)
  basename = File.basename(url.to_s,".*")
  folder =File.join('/mnt/openstudio/server/assets', basename)
  FileUtils.rm_rf(folder)
  puts "Creating clone of #{url} with options  #{options}."
  Git.clone(url,folder,options)
  return folder
end

def zip_all_results(uuid, cores=1)

  repo_folder = git_clean_rep('https://github.com/canmet-energy/btap_gather_results.git', options = { })

  %x[cd #{repo_folder} && bundle install && bundle exec ruby gather_results.rb -a #{uuid} ]

  # Finish up
  puts 'SUCCESS'
end

