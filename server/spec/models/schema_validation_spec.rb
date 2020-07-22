# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
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
# *******************************************************************************

require 'rails_helper'
require 'json-schema'

def get_osa(relative_path)
  osa = nil
  osa_path = File.expand_path("../../../#{relative_path}", __dir__)

  expect(File.exist?(osa_path)).to eq(true), "Could not find OSA file #{osa_path}"
  File.open(osa_path) do |f|
    osa = JSON.parse(f.read, symbolize_names: true)
  end
  expect(osa).to_not be_nil

  osa
end

def validate_osa(path, schema)
  osa = get_osa(path)

  puts "**** Checking validity of OSA: #{path} *****"

  errors = JSON::Validator.fully_validate(schema, osa)
  expect(errors.empty?).to eq(true), "OSA '#{path}' is not valid, #{errors}"
end

RSpec.describe 'OSA Schema' do
  before :all do
    @schema = nil
    schema_path = File.expand_path('../../app/lib/analysis_library/schema/osa.json', __dir__)
    expect(File.exist?(schema_path)).to be true
    File.open(schema_path) do |f|
      @schema = JSON.parse(f.read, symbolize_names: true)
    end
    expect(@schema).to_not be_nil
  end

  it 'should be a valid osa file' do
    # Make sure to use the copy of the spec/files/example_csv.json and da_measures.json as some
    # of the tests run in Docker and the /spec folder is not mounted, only the /server is mounted.
    [
        'server/spec/files/batch_datapoints/example_csv.json',
        'server/spec/files/batch_datapoints/example_csv_with_scripts.json',
        'server/spec/files/batch_datapoints/the_project.json',
        'server/spec/files/jsons/sweep_smalloffice.json',
        'server/spec/files/jsons/copy_of_root_da_measures.json',
        'server/spec/files/jsons/copy_of_root_example_csv.json',
        'server/spec/files/test_model/test_model.json',
    ].each { |f| validate_osa(f, @schema) }
  end
end
