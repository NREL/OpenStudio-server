require 'git'
require 'uri'

def git_clean_rep(url,options)
  url = URI.parse(url)
  basename = File.basename(url.to_s,".*")
  folder =File.join('/mnt/openstudio/server/assets', basename)
  FileUtils.rm_rf(folder)
  puts "Creating clone of #{url} with options  #{options}."
  %x[git clone #{url} #{folder}]
  #Git.clone(url,folder,options)
  return folder
end

def zip_all_results(uuid, cores=1)

  repo_folder = git_clean_rep('https://github.com/canmet-energy/btap_gather_results.git', options = { })
  puts repo_folder
  # %x[git clone https://github.com/canmet-energy/btap_gather_results.git /mnt/openstudio/server/assets/btap_gather_results]
  require "#{repo_folder}/gather_results.rb"
  start_gather_result(uuid, cores)
  #%x[cd /mnt/openstudio/server/assets/btap_gather_results && bundle install && bundle exec ruby gather_results.rb -a #{uuid} ]

  # Finish up
  puts 'SUCCESS'
end
