require 'rubygems'
require 'openstudio'
require 'csv'
require 'json'

# sql_query method
def sql_query(sql, report_name, query)
  val = nil
  result = sql.execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND #{query}")
  if result
    begin
      val = result.get
    rescue Exception => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      puts log_message
      val = 10e9
    end
  end
  val
end

def add_element(hash, var_name, value, xpath = nil)
  values_hash = {}
  values_hash['name'] = var_name

  # store correct datatype
  store_val = nil
  if value.nil?
    store_val = nil
  elsif value == 'true'
    store_val = true
  elsif value == 'false'
    store_val = false
  else
    test = value.to_s
    value = test.match('\.').nil? ? Integer(test) : Float(test) rescue test.to_s
    if value.is_a?(Fixnum) or value.is_a?(Float)
      store_val = value.to_f
    else
      store_val = value.to_s
    end
  end
  values_hash['value'] = store_val
  values_hash['xpath'] = xpath unless xpath.nil?

  hash['data']['variables'] << values_hash
end

# add results from sql method
def add_data(sql, query, hdr, area, val)
  row = []
  if val.nil?
    val = sql_query(sql, 'AnnualBuildingUtilityPerformanceSummary', query)
  end
  row << hdr
  if area.nil?
    row << val
  else
    row << (val * 1000) / area
  end
  row
end

begin
  # open sql file
  sql_file = OpenStudio::SqlFile.new(OpenStudio::Path.new('eplusout.sql'))

  # get building area
  bldg_area = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Building Area' AND RowName='Net Conditioned Building Area' AND ColumnName='Area'")
  # populate data array

  tbl_data = []
  tbl_data << add_data(sql_file, "TableName='Site and Source Energy' AND RowName='Total Site Energy' AND ColumnName='Energy Per Conditioned Building Area'", 'Total Energy (MJ/m2)', nil, nil)
  tbl_data << add_data(sql_file, "TableName='Site and Source Energy' AND RowName='Total Source Energy' AND ColumnName='Energy Per Conditioned Building Area'", 'Total Source Energy (MJ/m2)', nil, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Electricity'", 'Total Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Natural Gas'", 'Total Natural Gas (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heating' AND ColumnName='Electricity'", 'Heating Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heating' AND ColumnName='Natural Gas'", 'Heating Natural Gas (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Cooling' AND ColumnName='Electricity'", 'Cooling Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Lighting' AND ColumnName='Electricity'", 'Interior Lighting Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Exterior Lighting' AND ColumnName='Electricity'", 'Exterior Lighting Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Electricity'", 'Interior Equipment Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Natural Gas'", 'Interior Equipment Natural Gas (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Exterior Equipment' AND ColumnName='Electricity'", 'Exterior Equipment Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Fans' AND ColumnName='Electricity'", 'Fans Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Pumps' AND ColumnName='Electricity'", 'Pumps Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heat Rejection' AND ColumnName='Electricity'", 'Heat Rejection Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Humidification' AND ColumnName='Electricity'", 'Humidification Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Electricity'", 'Water Systems Electricity (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Natural Gas'", 'Water Systems Natural Gas (MJ/m2)', bldg_area, nil)
  tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Refrigeration' AND ColumnName='Electricity'", 'Refrigeration Electricity (MJ/m2)', bldg_area, nil)
  htg_hrs = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Heating' AND ColumnName='Facility'")
  clg_hrs = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Cooling' AND ColumnName='Facility'")
  tot_hrs = htg_hrs + clg_hrs
  tbl_data << add_data(sql_file, nil, 'Heating Hours Unmet (hr)', nil, htg_hrs)
  tbl_data << add_data(sql_file, nil, 'Cooling Hours Unmet (hr)', nil, clg_hrs)
  tbl_data << add_data(sql_file, nil, 'Total Hours Unmet (hr)', nil, tot_hrs)
  total_cost = sql_query(sql_file, 'Life-Cycle Cost Report', "TableName='Present Value by Category' AND RowName='Grand Total' AND ColumnName='Present Value'")
  tbl_data << add_data(sql_file, nil, 'Total Life Cycle Cost ($)', nil, total_cost)
  # close SQL file
  sql_file.close
  # transpose data
  tbl_rows = tbl_data.transpose
  # write electricity data to CSV
  CSV.open('eplustbl.csv', 'wb') do |csv|
    tbl_rows.each do |row|
      csv << row
    end
  end

  if File.exist?('eplustbl.csv')
    puts 'eplustbl.csv exists and parsing into JSON format'
    results = {}
    csv = CSV.read('eplustbl.csv')
    csv.transpose.each do |k, v|
      longname = k.gsub(/\(.*\)/, '').strip
      short_name = longname.downcase.gsub(' ', '_')
      units = k.match(/\(.*\)/)[0].gsub('(', '').gsub(')', '').downcase
      results[short_name.to_sym] = v.to_f
      results["#{short_name}_units".to_sym] = units
      results["#{short_name}_display_name".to_sym] = longname
    end

    puts 'saving results to json'
    # save out results
    File.open('eplustbl.json', 'w') { |f| f << JSON.pretty_generate(results) }
  end

rescue Exception => e
  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
  puts log_message

ensure
  # Always clean up
  require 'pathname'
  require 'fileutils'
  paths_to_rm = []
  paths_to_rm << Pathname.glob('*.osm')
  paths_to_rm << Pathname.glob('*.ini')
  paths_to_rm << Pathname.glob('*.idf')
  paths_to_rm << Pathname.glob('ExpandObjects')
  paths_to_rm << Pathname.glob('EnergyPlus')
  paths_to_rm << Pathname.glob('*.so')
  paths_to_rm << Pathname.glob('*.epw')
  paths_to_rm << Pathname.glob('*.idd')
  # paths_to_rm << Pathname.glob("*.audit")
  # paths_to_rm << Pathname.glob("*.bnd")
  paths_to_rm << Pathname.glob('*.mtd')
  paths_to_rm << Pathname.glob('*.rdd')
  paths_to_rm << Pathname.glob('packaged_measures')
  paths_to_rm.each { |p| FileUtils.rm_rf(p) }
end
