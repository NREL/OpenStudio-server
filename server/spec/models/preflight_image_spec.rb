describe PreflightImage do
  before :all do
    # delete all the analyses
    Project.delete_all
    Analysis.delete_all
    DataPoint.delete_all
    FactoryGirl.create(:project_with_analyses).analyses

    @project = Project.first
    @analysis = @project.analyses.first
  end

  it "should add a variable and preflight image" do
    new_var = Variable.new
    new_var.save!
    @analysis.variables << new_var 
    pfi = PreflightImage.add_from_disk(new_var.id, "histogram", "../files/r_plot_histogram.png")
    new_var.preflight_images << pfi unless new_var.preflight_images.include?(pfi)
    
    expect(new_var.preflight_images.count).to eq(1)
  end
end   
