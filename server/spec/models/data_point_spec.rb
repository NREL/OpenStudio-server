describe DataPoint do
  before :each do
    Project.delete_all
    Analysis.delete_all
    DataPoint.delete_all
    FactoryGirl.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
    @data_point = @analysis.data_points.first
  end

  it 'should have an analysis' do
    @project.analyses.should_not be_nil
  end

  it 'should have uuid and id the same' do
    @data_point.id.should eq(@data_point.uuid)
  end

  after :each do
  end
end
