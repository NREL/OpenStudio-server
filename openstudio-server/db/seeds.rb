# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

jsonfile = "/vagrant/prototype/pat/server_problem.json"
if File.exists?(jsonfile)
  json = JSON.parse(File.read(jsonfile), :symbolize_names => true)
  puts json

  project = Project.find_or_create_by(:name => "Example 1")
  project.create_single_analysis("PAT Example", "Batch")
  project.save!

  problem = project.get_problem("Batch")

  problem.load_variables_from_pat_json(json)
  problem.save!

else
  puts "file does not exist"
end
exit

json = ActiveSupport::JSON.decode(File.read('/vagrant/prototype/pat/server_problem.json'))
puts json

json.each do |a|
  Project.create!(a['data'], without_protection: true)
end


=begin
p.save
puts p.inspect
a = p.analyses.find_or_create_by(name: "test analysis")
a.problems.find_or_create_by(name: "test problem")
(1..50).each do |i|
  m = a.data_points.find_or_create_by(name: "test model #{i}")
  m['results'] = {}
  ['eui','abc','def','ghi'].each do |w|
    m['results'][w] = 50 * rand(502)
  end

  m.save
end

p.save
=end
