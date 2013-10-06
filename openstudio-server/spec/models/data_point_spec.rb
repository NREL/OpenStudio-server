describe DataPoint do
  before :each do
    Project.destroy_all
    Analysis.destroy_all
    DataPoint.destroy_all
    @project = FactoryGirl.create :project
    @analysis = FactoryGirl.create :analysis
    @data_point = FactoryGirl.create :data_point

  end

  it "should have an analysis" do
    @data_point.analysis.should_not be_nil
  end

  it "should have uuid and id the same" do
    @data_point.id.should eq(@data_point.uuid)
  end

  it "should be able to load the openstudio JSON" do
    testfile = File.join(File.dirname(__FILE__), "..", "example_data", "data_point_result.json")
    File.exists?(testfile).should be_true

    json = JSON.parse(File.read(testfile), :symbolize_names => true)
    json[:data_point].nil?.should be_false
    json["data_point"].nil?.should be_true

    json[:metadata].nil?.should be_false

    @data_point.output.should be_nil

    @data_point.output = json
    @data_point.output.should_not be_nil
    @data_point.save!
    @data_point.output[:data_point][:complete].should be_true


  end

  after :each do
  end
end