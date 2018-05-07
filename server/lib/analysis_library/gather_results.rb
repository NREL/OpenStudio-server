#!/usr/bin/env ruby
# CLI tool to allow for creating a version of the localResults directory on the server
# This should be employed as a server finalizations script for BuildStock PAT projects
# Written by Henry R Horsey III (henry.horsey@nrel.gov)
# Created October 5th, 2017
# Last updated on October 6th, 2017
# Copywrite the Alliance for Sustainable Energy LLC
# License: BSD3+1


require 'rest-client'
require 'fileutils'
require 'zip'
require 'parallel'
require 'optparse'
require 'json'
require 'base64'
require 'colored'
require 'csv'

# Unzip an archive to a destination directory using Rubyzip gem
#
# @param archive [:string] archive path for extraction
# @param dest [:string] path for archived file to be extracted to
def unzip_archive(archive, dest)
  # Adapted from examples at...
  # https://github.com/rubyzip/rubyzip
  # http://seenuvasan.wordpress.com/2010/09/21/unzip-files-using-ruby/
  Zip::File.open(archive) do |zf|
    zf.each do |f|
      f_path = File.join(dest, f.name)
      if (f.name == 'enduse_timeseries.csv') || (f.name == 'measure_attributes.json')
        FileUtils.mkdir_p(File.dirname(f_path))
        zf.extract(f, f_path) unless File.exist?(f_path) # No overwrite
      end
    end
  end
end

# Gather the required files from each zip file on the server for an analysis
#
# @param aid [:string] analysis uuid to retrieve files for
# @param num_cores [:int] available cores to the executing agent
def gather_output_results(aid, num_cores=1)
  # Ensure required directories exist and create if appropriate
  basepath = '/mnt/openstudio/server/assets/data_points'
  unless Dir.exists? basepath
    fail "ERROR: Unable to find base data point path #{basepath}"
  end
  resultspath = "/mnt/openstudio/server/assets/results/#{aid}/osw_files/"
  outputpath = "/mnt/openstudio/server/assets/results/#{aid}/"

  simulations_json_folder = outputpath
  
  FileUtils.mkdir_p(outputpath)
  osw_folder = "#{outputpath}/osw_files"
  FileUtils.mkdir_p(osw_folder)
  output_folder = "#{outputpath}/output"
  FileUtils.mkdir_p(output_folder)
  File.open("#{outputpath}/missing_files.log", 'wb') { |f| f.write("") }
  File.open("#{outputpath}/missing_files.log", 'w') {|f| f.write("") }
  File.open("#{simulations_json_folder}/simulations.json", 'w'){}

  puts "creating results folder #{resultspath}"
  unless Dir.exists? resultspath
    FileUtils.mkdir_p resultspath
  end

  # Determine all data points to download from the REST API
  astat = JSON.parse RestClient.get("http://web:80/analyses/#{aid}/status.json", headers={})
  dps = astat['analysis']['data_points'].map { |dp| dp['id'] }

  # Ensure there are datapoints to download
  if dps.nil? || dps.empty?
    fail "ERROR: No datapoints found. Analysis #{aid} completed with no datapoints"
  end

  # Find all data points asset ids
  assetids = {}
  dps.each do |dp|
    begin
      dp_res_files = JSON.parse(RestClient.get("http://web:80/data_points/#{dp}.json", headers={}))['data_point']['result_files']
      puts dp_res_files
      if dp_res_files.nil?
        puts "Unable to find related files for data point #{dp}"
      else
        osws = dp_res_files.select { |file| file['attachment_file_name'] == "out.osw" }
        if osws.empty?
          puts "No osw files found attached to data point #{dp}"
        elsif osws.length > 1
          puts "More than one osw file is attached to data point #{dp}, skipping"
        else
          assetids[dp] = osws[0]['_id']['$oid']
        end
      end
    rescue RestClient::ExceptionWithResponse
      puts "Unable to retrieve json from REST API for data point #{dp}"
    end
  end

  # Register and remove missing datapoint zip files
  available_dps = Dir.entries basepath
  missing_dps = []
  dps.each { |dp| missing_dps << dp unless available_dps.include? assetids[dp] }
  puts "Missing #{100.0 * missing_dps.length.to_f / dps.length}% of data point zip files"
  unless missing_dps.empty?
    logfile = File.join resultspath, 'missing_dps.log'
    puts "Writing missing datapoint UUIDs to #{logfile}"
    File.open(logfile, 'wb') do |f|
      f.write JSON.dump(missing_dps)
    end
  end

  # Only download datapoints which do not already exist
  exclusion_list = Dir.entries resultspath
  
  assetids.keys.each do |dp|
    unless (exclusion_list.include? dp) || (missing_dps.include? dp)
      uuid = dp
      #OSW file name
      osw_file = File.join(basepath, assetids[dp], 'files', 'original', 'out.osw')
      #The folder path with the UUID of the datapoint in the path. 
      write_dir = File.join(resultspath, dp)
      #Makes the folder for the datapoint. 
      FileUtils.mkdir_p write_dir unless Dir.exists? write_dir
      #Gets the basename from the full path of of the osw file (Should always be out.osw) 
      osw_basename = File.basename(osw_file)
      #Create the new osw file name name. 
      new_osw = "#{write_dir}/#{osw_basename}"
      puts new_osw
      #This is the copy command to copy the osw_file to the new results folder. 
      FileUtils.cp(osw_file,"#{write_dir}/#{osw_basename}")

      results = JSON.parse(File.read(osw_file))
     
      # change the output folder directory based on building_type and climate_zone
      # get building_type and climate_zone from create_prototype_building measure if it exists
      results['steps'].each do |measure|
        next unless measure["name"] == "btap_create_necb_prototype_building"
        #template = measure["arguments"]["template"]
        building_type = measure["arguments"]["building_type"]
        #climate_zone = measure["arguments"]["climate_zone"]
        #remove the .epw suffix
        epw_file = measure["arguments"]["epw_file"].gsub(/\.epw/,"")
        output_folder = "#{outputpath}/output/#{building_type}/#{epw_file}"
        #puts output_folder
        FileUtils.mkdir_p(output_folder)
      end
       
         #parse the downloaded osw files and check if the datapoint failed or not
      #if failed download the eplusout.err and sldp_log files for error logging
      failed_log_folder = "#{output_folder}/failed_run_logs"
      check_and_log_error(results,outputpath,uuid,failed_log_folder, aid)

      #itterate through all the steps of the osw file
          results['steps'].each do |measure|
            #puts "measure.name: #{measure['name']}"
            found_osm = false
            found_json = false

            # if the measure is openstudioresults, then download the eplustbl.htm and the pretty report [report.html]
            if measure["name"] == "openstudio_results" && measure.include?("result")
              measure["result"]["step_values"].each do |values|
                # extract the eplustbl.html blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'eplustbl_htm'
                  eplustbl_htm_zip = values['value']
                  eplustbl_htm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( eplustbl_htm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/eplus_table")
                  File.open("#{output_folder}/eplus_table/#{uuid}-eplustbl.htm", 'wb') {|f| f.write(eplustbl_htm_string) }
                  #puts "#{uuid}-eplustbl.htm ok"
                end
                # extract the pretty report.html blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'report_html'
                  report_html_zip = values['value']
                  report_html_string =  Zlib::Inflate.inflate(Base64.strict_decode64( report_html_zip ))
                  FileUtils.mkdir_p("#{output_folder}/os_report")
                  File.open("#{output_folder}/os_report/#{uuid}-os-report.html", 'wb') {|f| f.write(report_html_string) }
                  #puts "#{uuid}-os-report.html ok"
                end
              end
            end

            # if the measure is view_model, then extract the 3d.html model and save it
            if measure["name"] == "btap_view_model" && measure.include?("result")
              measure["result"]["step_values"].each do |values|
                if values["name"] == 'view_model_html_zip'
                  view_model_html_zip = values['value']
                  view_model_html =  Zlib::Inflate.inflate(Base64.strict_decode64( view_model_html_zip ))
                  FileUtils.mkdir_p("#{output_folder}/3d_model")
                  File.open("#{output_folder}/3d_model/#{uuid}_3d.html", 'wb') {|f| f.write(view_model_html) }
                  #puts "#{uuid}-eplustbl.htm ok"
                end
              end
            end

            # if the measure is btapresults, then extract the osw file and qaqc json
            # While processing the qaqc json file, add it to the simulations.json file
            if measure["name"] == "btap_results" && measure.include?("result")
              measure["result"]["step_values"].each do |values|
                # extract the model_osm_zip blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'model_osm_zip'
                  found_osm = true
                  model_osm_zip = values['value']
                  osm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( model_osm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/osm_files")
                  File.open("#{output_folder}/osm_files/#{uuid}.osm", 'wb') {|f| f.write(osm_string) }
                  #puts "#{uuid}.osm ok"
                end

                # extract the btap_results_hourly_data_8760 blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'btap_results_hourly_data_8760'
                  model_osm_zip = values['value']
                  osm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( model_osm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/8760_files")
                  File.open("#{output_folder}/8760_files/#{uuid}-8760_hourly_data.csv", 'w+') {|f| f.write(osm_string) }
                  #puts "#{uuid}.osm ok"
                end

                # extract the btap_results_hourly_custom_8760 blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'btap_results_hourly_custom_8760'
                  model_osm_zip = values['value']
                  osm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( model_osm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/8760_files")
                  File.open("#{output_folder}/8760_files/#{uuid}-8760_hour_custom.csv", 'w+') {|f| f.write(osm_string) }
                  #puts "#{uuid}.osm ok"
                end

                # extract the btap_results_monthly_7_day_24_hour_averages blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'btap_results_monthly_7_day_24_hour_averages'
                  model_osm_zip = values['value']
                  osm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( model_osm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/8760_files")
                  File.open("#{output_folder}/8760_files/#{uuid}-mnth_24_hr_avg.csv", 'w+') {|f| f.write(osm_string) }
                  #puts "#{uuid}.osm ok"
                end

                # extract the btap_results_monthly_24_hour_weekend_weekday_averages blob data from the 
                #osw file and save it in the output folder
                if values["name"] == 'btap_results_monthly_24_hour_weekend_weekday_averages'
                  model_osm_zip = values['value']
                  osm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( model_osm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/8760_files")
                  File.open("#{output_folder}/8760_files/#{uuid}-mnth_weekend_weekday.csv", 'w+') {|f| f.write(osm_string) }
                  #puts "#{uuid}.osm ok"
                end

                # extract the btap_results_enduse_total_24_hour_weekend_weekday_averages blob data 
                # from the osw file and save it in the output folder
                if values["name"] == 'btap_results_enduse_total_24_hour_weekend_weekday_averages'
                  model_osm_zip = values['value']
                  osm_string =  Zlib::Inflate.inflate(Base64.strict_decode64( model_osm_zip ))
                  FileUtils.mkdir_p("#{output_folder}/8760_files")
                  File.open("#{output_folder}/8760_files/#{uuid}-endusetotal.csv", 'w+') {|f| f.write(osm_string) }
                  #puts "#{uuid}.osm ok"
                end


                # extract the qaqc json blob data from the osw file and save it
                # in the output folder
                if values["name"] == 'btap_results_json_zip'
                  found_json = true
                  btap_results_json_zip = values['value']
                  json_string =  Zlib::Inflate.inflate(Base64.strict_decode64( btap_results_json_zip ))
                  json = JSON.parse(json_string)
                  # indicate if the current model is a baseline run or not
                  # json['is_baseline'] = "#{flags[:baseline]}"

                  #add ECM data to the json file
                  measure_data = []
                  results['steps'].each_with_index do |measure, index|
                    step = {}
                    measure_data << step
                    step['name'] = measure['name']
                    step['arguments'] = measure['arguments']
                    if measure.has_key?('result')
                      step['display_name'] = measure['result']['measure_display_name']
                      step['measure_class_name'] = measure['result']['measure_class_name']
                    end
                    step['index'] = index
                    # measure is an ecm if it starts with ecm_ (case ignored)
                    step['is_ecm'] = !(measure['name'] =~ /^ecm_/i).nil? # returns true if measure name starts with 'ecm_' (case ignored)
                  end

                  json['measures'] = measure_data

                  FileUtils.mkdir_p("#{output_folder}/qaqc_files")
                  File.open("#{output_folder}/qaqc_files/#{uuid}.json", 'wb') {|f| f.write(JSON.pretty_generate(json)) }

                  # append qaqc data to simulations.json
                  process_simulation_json(json,simulations_json_folder, uuid)
                  puts "#{uuid}.json ok"
                end # values["name"] == 'btap_results_json_zip'
              end
            end # if measure["name"] == "btapresults" && measure.include?("result")
          end # of grab step files

    end
  end
end


#parse the downloaded osw files and check if the datapoint failed or not
#if failed download the eplusout.err and sldp_log files for error logging
#
# @param results [:hash] contains content of the out.osw file
# @param output_folder [:string] root folder where the csv log needs to be created
# @param uuid [:string] uuid of the datapoint. used to download the sdp log file if the datapoint has failed
# @param failed_output_folder [:string] root folder of the sdp log files
def check_and_log_error(results,output_folder,uuid,failed_output_folder, aid)
  if results['completed_status'] == "Fail"
    FileUtils.mkdir_p(failed_output_folder) # create failed_output_folder
    log_k, log_f = get_log_file(aid, uuid, failed_output_folder)
    # log_k => Boolean which determines if the log file has been downloaded successfully
    # log_f => path of the downloaded log file

    #create the csv file if it does not exist
    # this csv file will contain the building information with the eplusout.err log and the sdp_error log
    File.open("#{output_folder}/failed_run_error_log.csv", 'w'){|f| f.write("") } unless File.exists?("#{output_folder}/failed_run_error_log.csv")

    # output the errors to the csv file
    CSV.open("#{output_folder}/failed_run_error_log.csv", 'a') do |f|
      results['steps'].each do |measure|
        next unless measure["name"] == "btap_create_necb_prototype_building"
        out = {}
        eplus = "" # stores the eplusout error file

        # check if the eplusout.err file was generated by the run
        if results.has_key?('eplusout_err')
          eplus = results['eplusout_err']
          # if eplusout.err file has a fatal error, only store the error,
          # if not entire file will be stored
          match = eplus.to_s.match(/\*\*  Fatal  \*\*.+/)
          eplus = match unless match.nil?
        else
          eplus = "EPlusout.err file not generated by osw"
        end

        log_content = ""
        # ckeck if the log file has been downloaded successfully.
        # if the log file has been downloaded successfully, then match the last ERROR
        if log_k
          log_file = File.read(log_f)
          log_match = log_file.scan(/((\[.{12,18}ERROR\]).+?)(?=\[.{12,23}\])/m)
          #puts "log_match #{log_match}\n\n".cyan
          log_content = log_match.last unless log_match.nil?
          #puts "log_match #{log_match}\n\n".cyan
        else
          log_content = "No Error log Found"
        end

        # write building_type, climate_zone, epw_file, template, uuid, eplusout.err
        # and error log content to the comma delimited file
        out = %W{#{measure['arguments']['building_type']} #{measure['arguments']['climate_zone']} #{measure['arguments']['epw_file']} #{measure['arguments']['template']} #{uuid} #{eplus} #{log_content}}
        # make the write process thread safe by locking the file while the file is written
        f.flock(File::LOCK_EX)
        f.puts out
        f.flock(File::LOCK_UN)
      end
    end #File.open("#{output_folder}/FAIL.log", 'a')
  end #results['completed_status'] == "Fail"
end

# This method will append qaqc data to simulations.json
#
# @param json [:hash] contains original qaqc json file of a datapoint
# @param simulations_json_folder [:string] root folder of the simulations.json file
def process_simulation_json(json,simulations_json_folder,uuid)
  #modify the qaqc json file to remove eplusout.err information,
  # and add separate building information and uuid key
  #json contains original qaqc json file on start
  if json.has_key?('eplusout_err')
    json['eplusout_err']['warnings'] = json['eplusout_err']['warnings'].size
    json['eplusout_err']['severe'] = json['eplusout_err']['severe'].size
    json['eplusout_err']['fatal'] = json['eplusout_err']['fatal'].size
  else
    File.open("#{simulations_json_folder}/missing_files.log", 'a') {|f| f.write("ERROR: Unable to find eplusout_err #{uuid}.json\n") }
  end
  json['run_uuid'] = uuid
  #puts "json['run_uuid'] #{json['run_uuid']}"
  bldg = json['building']['name'].split('-')
  json['building_type'] = bldg[1]
  json['template'] = bldg[0]

  #write the simulations.json file thread safe
  File.open("#{simulations_json_folder}/simulations.json", 'a'){|f|
    f.flock(File::LOCK_EX)
    # add a [ to the simulations.json file if it is being written for the first time
    # if not, then add a comma
    if File.zero?("#{simulations_json_folder}/simulations.json")
      f.write("[#{JSON.generate(json)}")
    else
      f.write(",#{JSON.generate(json)}")
    end
    f.flock(File::LOCK_UN)
  }
end

# This method will download the status of the entire analysis which includes the datapoint
# status such as "completed normal" or "datapoint failure"
#
# @param datapoint_id [:string] Datapoint ID
# @param file_name [:string] Filename to be downloaded for the datapoint, with extension
# @param save_directory [:string] path of output location, without filename extension
# @return [downloaded, file_path_and_name] [:array]: [downloaded] boolean - true if download is successful; [file_path_and_name] String path and file name of the downloaded file with extension
def get_log_file (analysis_id, data_point_id, save_directory = '.')
  downloaded = false
  file_path_and_name = nil
  unless analysis_id.nil?
    data_points = nil
    resp =  RestClient.get("http://web:80/analyses/#{analysis_id}/status.json", headers={})
    #resp = @conn.get "analyses/#{analysis_id}/status.json"
    puts "status.json OK".green
    puts resp.class.name
    if resp.code == 200
      array = JSON.parse(resp.body)
      #puts JSON.pretty_generate(array)
      data_points = array['analysis']['data_points']
      data_points.each do |dp|
        next unless dp['_id'] == data_point_id
        puts "Checking #{dp['_id']}: Status: #{dp["status_message"]}".green
        log_resp = RestClient.get("http://web:80/data_points/#{dp['_id']}.json", headers={:accept => :json})
        #log_resp = @conn.get "data_points/#{dp['_id']}.json"
        if log_resp.code == 200
          sdp_log_file = JSON.parse(log_resp.body)['data_point']['sdp_log_file']
          file_path_and_name = "#{save_directory}/#{dp['_id']}-sdp.log"
          File.open(file_path_and_name, 'wb') { |f|
            sdp_log_file.each { |line| f.puts "#{line}"  }
          }
          downloaded = true
        else
          puts log_resp
        end
      end
    end
  end
  return [downloaded, file_path_and_name]
end #get_log_file

# Source: https://github.com/rubyzip/rubyzip
# This is a simple example which uses rubyzip to
# recursively generate a zip file from the contents of
# a specified directory. The directory itself is not
# included in the archive, rather just its contents.
#
# Usage:
#   directory_to_zip = "/tmp/input"
#   output_file = "/tmp/out.zip"
#   zf = ZipFileGenerator.new(directory_to_zip, output_file)
#   zf.write()
class ZipFileGenerator
  # Initialize with the directory to zip and the location of the output archive.
  def initialize(input_dir, output_file)
    @input_dir = input_dir
    @output_file = output_file
  end

  # Zip the input directory.
  def write
    entries = Dir.entries(@input_dir) - %w(. ..)

    ::Zip::File.open(@output_file, ::Zip::File::CREATE) do |zipfile|
      write_entries entries, '', zipfile
    end
  end

  private

  # A helper method to make the recursion work.
  def write_entries(entries, path, zipfile)
    entries.each do |e|
      zipfile_path = path == '' ? e : File.join(path, e)
      disk_file_path = File.join(@input_dir, zipfile_path)
      puts "Deflating #{disk_file_path}"

      if File.directory? disk_file_path
        recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
      else
        put_into_archive(disk_file_path, zipfile, zipfile_path)
      end
    end
  end

  def recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
    zipfile.mkdir zipfile_path
    subdir = Dir.entries(disk_file_path) - %w(. ..)
    write_entries subdir, zipfile_path, zipfile
  end

  def put_into_archive(disk_file_path, zipfile, zipfile_path)
    zipfile.get_output_stream(zipfile_path) do |f|
      f.write(File.open(disk_file_path, 'rb').read)
    end
  end
end

def zip_all_results(uuid, cores=1)
  # Initialize optionsParser ARGV hash
  options = {}
  options[:analysis_id] = uuid
  options[:num_cores] = cores

  # Sanity check inputs
  fail 'analysis UUID not specified' if options[:analysis_id].nil?
  fail 'enter a number of avaialble cores greater than zero' if options[:num_cores].to_i == 0

  # Gather the required files
  Zip.warn_invalid_date = false
  gather_output_results(options[:analysis_id], options[:num_cores])

  # Zip Results
  directory_to_zip = "/mnt/openstudio/server/assets/results/#{uuid}"
  output_file = "/mnt/openstudio/server/assets/results.#{uuid}.zip"
  puts "Zipping Files...".cyan
  zf = ZipFileGenerator.new(directory_to_zip, output_file)
  zf.write()


  # Finish up
  puts 'SUCCESS'
end

