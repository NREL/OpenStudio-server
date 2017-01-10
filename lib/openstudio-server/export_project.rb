#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#*******************************************************************************

require 'openstudio'
require 'fileutils'

# ARGV[0] - the name of the project to export, e.g. 'PATTest'
#
# This script will export the named project to ARGV[0] + 'Export'
#
# Run this script in the directory where the project lives, e.g.
#
# cd openstudio-server/testing
# ruby ../lib/openstudio-server/export_project.rb PATTest

project_dir = ARGV[0].to_s
export_dir = project_dir + "Export"
batch_size = 50

puts "exporting " + project_dir + " to " + export_dir

OpenStudio::Application::instance.processEvents

# load project from disk
project = OpenStudio::AnalysisDriver::SimpleProject::open(OpenStudio::Path.new(project_dir)).get

# delete existing export
if File.exists?(export_dir)
  OpenStudio::removeDirectory(OpenStudio::Path.new(export_dir))
end

# export project
Dir.mkdir(export_dir)
# analysis.json
options = OpenStudio::Analysis::AnalysisSerializationOptions.new(project.projectDir)
project.analysis.saveJSON(OpenStudio::Path.new(export_dir + "/analysis.json"),options)
# project.zip
project_zip_file = project.zipFileForCloud
FileUtils.copy_file("#{project_zip_file}", export_dir + "/project.zip")
# data_points_#{batch_index}.json
batch_index = 1
batch = OpenStudio::Analysis::DataPointVector.new
project.analysis.dataPoints.each do |dataPoint|
  if batch.size == 50
    OpenStudio::Analysis::saveJSON(batch,OpenStudio::Path.new(export_dir + "/data_points_#{batch_index}"))
    batch_index += 1
    batch.clear    
  end
  batch << dataPoint
end
if not batch.empty?
  OpenStudio::Analysis::saveJSON(batch,OpenStudio::Path.new(export_dir + "/data_points_#{batch_index}"))
end

