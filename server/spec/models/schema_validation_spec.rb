# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
  expect(osa).not_to be_nil

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
    expect(@schema).not_to be_nil
  end

  it 'is a valid osa file' do
    # Make sure to use the copy of the spec/files/example_csv.json and da_measures.json as some
    # of the tests run in Docker and the /spec folder is not mounted, only the /server is mounted.
    [
      'server/spec/files/batch_datapoints/example_csv.json',
      'server/spec/files/batch_datapoints/example_csv_with_scripts.json',
      'server/spec/files/batch_datapoints/the_project.json',
      'server/spec/files/jsons/sweep_smalloffice.json',
      'server/spec/files/jsons/copy_of_root_da_measures.json',
      'server/spec/files/jsons/copy_of_root_example_csv.json',
      'server/spec/files/test_model/test_model.json'
    ].each { |f| validate_osa(f, @schema) }
  end
end
