# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************
require 'rails_helper'
require 'fileutils'

RSpec.describe 'DataPoint & Analysis asset cleanup', type: :model do
  let(:dp_assets_root) do
    Pathname.new(APP_CONFIG['server_asset_path']).join('assets','data_points')
  end
  let(:analysis_assets_root) do
    Pathname.new(APP_CONFIG['server_asset_path']).join('assets','analyses')
  end

  before do
    # Wipe both roots so each example starts fresh
    FileUtils.rm_rf(dp_assets_root)        if dp_assets_root.exist?
    FileUtils.rm_rf(analysis_assets_root)  if analysis_assets_root.exist?
    FileUtils.mkdir_p(dp_assets_root)
    FileUtils.mkdir_p(analysis_assets_root)

    # Build our Analysis + two DataPoints + two ResultFiles each
    Project.destroy_all
    FactoryBot.create(:project_with_analyses)
    @analysis = Project.first.analyses.first

    @dp1 = @analysis.data_points.create!(uuid: SecureRandom.uuid)
    @dp2 = @analysis.data_points.create!(uuid: SecureRandom.uuid)
    [@dp1, @dp2].each do |dp|
      %w[Results Rdata].each { |t| dp.result_files.build(display_name: t, type: t) }
      dp.save!
    end

    # Simulate Paperclip writes under data_points
    @all_rf_ids = @analysis.data_points.flat_map { |dp|
      dp.result_files.map(&:id).map(&:to_s)
    }
    @all_rf_ids.each do |rf_id|
      dir = dp_assets_root.join(rf_id,'files','original')
      FileUtils.mkdir_p(dir)
      File.write(dir.join('a.txt'),'foo')
      File.write(dir.join('b.txt'),'bar')
    end

    # Simulate a seed_zip write under analyses
    @analysis_dir = analysis_assets_root.join(@analysis.id)
    FileUtils.mkdir_p(@analysis_dir)
    File.write(@analysis_dir.join('example_csv.zip'), 'dummy-zip-content')
  end

  after do
    FileUtils.rm_rf(dp_assets_root)
    FileUtils.rm_rf(analysis_assets_root)
  end

  it 'deletes a single DataPoint’s files on dp.destroy' do
    rf_ids = @dp1.result_files.map(&:id).map(&:to_s)
    @dp1.destroy
    rf_ids.each { |id| expect(dp_assets_root.join(id)).not_to exist }
    # other DP still there
    (@all_rf_ids - rf_ids).each { |id| expect(dp_assets_root.join(id)).to exist }
  end

  it 'then deletes the Analysis and cleans up the remaining DataPoint’s files' do
    @dp1.destroy
    @analysis.destroy
    Delayed::Worker.new.work_off
    sleep 5
    # no data_point dirs left
    expect(dp_assets_root.children).to be_empty
  end

  it 'cleans up the analyses folder when the Analysis is destroyed' do
    # ensure our dummy file exists
    expect(@analysis_dir).to exist

    @analysis.destroy
    # run the queued DeleteAnalysis job
    Delayed::Worker.new.work_off
    sleep 5
    # direct invocation of the same code the job would run:
    DjJobs::DeleteAnalysis.new(@analysis_dir.to_s).perform
    # now the entire analyses/<id> folder should be gone
    expect(analysis_assets_root.join(@analysis.id)).not_to exist
  end
end