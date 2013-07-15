# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Emanuel', :city => cities.first)




p = Project.find_or_create_by(:name => "test")
p.save
puts p.inspect
a = p.analyses.find_or_create_by(name: "test analysis")
a.problems.find_or_create_by(name: "test problem")
puts a.inspect
(1..50).each do |i|
  m = a.data_points.find_or_create_by(name: "test model #{i}")
  m['results'] = {}
  ['eui','abc','def','ghi'].each do |w|
    m['results'][w] = 50 * rand(502)
  end
  m.save
end

p.save
p = Project.find_or_create_by(:name => 'test 2')
#a = p.analyses.find_or_create_by(:name => 'test analysis 2')
