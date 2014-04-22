require 'spec_helper'

# this is not a class based spec, rather a process based script to test the running of the
# energyplus model
describe 'RunOpenStudioWorkflow' do

  before :all do
    # create a directory to run the simulation with the required files
    @library_path = '/data/worker-nodes'
    unless Dir.exists?(@library_path)
      @library_path = File.expand_path('../../../../worker-nodes')
    end

    require "#{@library_path}/workflow_helpers"

    # need to create an example project
  end

  it "should not run an unknown model" do
    options =  {:run_data_point_filename => 'run_openstudio_workflow.rb', :uuid => "bad_model"}
    WorkflowHelpers.prepare_run_directory(@library_path, "#{@library_path}/test/#{options[:uuid]}", options)

    # TODO move the command construction to a helper method
    command = "ruby -I#{@library_path} #{@library_path}/test/#{options[:uuid]}/#{options[:run_data_point_filename]} -u #{options[:uuid]} -d #{@library_path}/test"
    result = `#{command}`
    expect(result).to_not be_nil
    result = result.split("\n").last if result
    expect(result).to eq('NA')
  end

  it "should run a known model" do
    options =  {:run_data_point_filename => 'run_openstudio_workflow.rb', :uuid => "example1"}
    WorkflowHelpers.prepare_run_directory(@library_path, "#{@library_path}/test/#{options[:uuid]}", options)

    # TODO move the command construction to a helper method
    command = "ruby -I#{@library_path} #{@library_path}/test/#{options[:uuid]}/#{options[:run_data_point_filename]} -u #{options[:uuid]} -d #{@library_path}/test"
    result = `#{command}`
    expect(result).to_not be_nil
    result = result.split("\n").last if result
    #expect(result).to_not eq('NA')
  end

  after :all do
    #FileUtils.rm_rf("#{@library_path}/test")
  end
end
