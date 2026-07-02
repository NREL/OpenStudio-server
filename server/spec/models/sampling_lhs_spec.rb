# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

# Pure-Ruby LHS sampling backend (no Rserve required)
RSpec.describe AnalysisLibrary::Sampling::Lhs, type: :model do
  before do
    begin
      Project.destroy_all
      Delayed::Job.destroy_all
    rescue Errno::EACCES
      puts 'Cannot unlink files, will try and continue'
    end

    @project = Project.create(name: 'ruby lhs sampling test')
    @analysis = @project.analyses.create(
      name: 'ruby lhs',
      display_name: 'ruby lhs',
      problem: {
        'algorithm' => {
          'number_of_samples' => 10,
          'sample_method' => 'all_variables',
          'sampling_backend' => 'ruby',
          'seed' => 1979
        }
      }
    )
  end

  def make_var(attrs)
    defaults = {
      analysis_id: @analysis.id,
      uuid: SecureRandom.uuid,
      perturbable: true
    }
    Variable.create!(defaults.merge(attrs))
  end

  it 'stratifies a uniform variable across its range' do
    var = make_var(name: 'uniform_var', uncertainty_type: 'uniform',
                   lower_bounds_value: 0.0, upper_bounds_value: 10.0, modes_value: 5.0)

    lhs = described_class.new(1979)
    samples, var_types, min_max, var_names = lhs.sample_all_variables([var], 10)

    expect(var_types).to eq ['continuous']
    expect(var_names).to eq ['uniform_var']
    expect(min_max[:min]).to eq [0.0]
    expect(min_max[:max]).to eq [10.0]

    values = samples[var.id.to_s]
    expect(values.size).to eq 10
    expect(values).to all(be >= 0.0)
    expect(values).to all(be <= 10.0)
    # uniform quantile is linear, so LHS strata map to [i, i+1) bins
    expect(values.map { |v| v.floor }.sort).to eq (0...10).to_a
    expect(var.reload.r_index).to eq 1
  end

  it 'samples discrete variables from the given values with roughly the given weights' do
    var = make_var(name: 'discrete_var', uncertainty_type: 'discrete',
                   discrete_values_and_weights: [
                     { 'value' => 'red', 'weight' => 0.75 },
                     { 'value' => 'blue', 'weight' => 0.25 }
                   ])

    n = 400
    lhs = described_class.new(42)
    samples, var_types, = lhs.sample_all_variables([var], n)

    expect(var_types).to eq ['discrete']
    values = samples[var.id.to_s]
    expect(values.uniq.sort).to match_array %w(blue red)
    blue_fraction = values.count('blue') / n.to_f
    # LHS stratification pins discrete frequencies almost exactly to the weights
    expect(blue_fraction).to be_within(0.02).of(0.25)
  end

  it 'samples integer sequences only from seq(lower, upper, by)' do
    var = make_var(name: 'seq_var', uncertainty_type: 'integer_sequence',
                   lower_bounds_value: 1, upper_bounds_value: 9, modes_value: 2)

    lhs = described_class.new(7)
    samples, var_types, = lhs.sample_all_variables([var], 25)

    expect(var_types).to eq ['discrete']
    expect(samples[var.id.to_s].uniq.sort).to match_array [1.0, 3.0, 5.0, 7.0, 9.0]
  end

  it 'clamps normal samples to the variable bounds via uniform resampling' do
    var = make_var(name: 'normal_var', uncertainty_type: 'normal',
                   modes_value: 0.0, stddev_value: 1.0,
                   lower_bounds_value: -1.0, upper_bounds_value: 1.0)

    lhs = described_class.new(11)
    samples, = lhs.sample_all_variables([var], 50)

    values = samples[var.id.to_s]
    expect(values).to all(be >= -1.0)
    expect(values).to all(be <= 1.0)
  end

  it 'is reproducible for a given seed' do
    var = make_var(name: 'uniform_var', uncertainty_type: 'uniform',
                   lower_bounds_value: 0.0, upper_bounds_value: 1.0, modes_value: 0.5)

    s1, = described_class.new(123).sample_all_variables([var], 8)
    s2, = described_class.new(123).sample_all_variables([var], 8)
    s3, = described_class.new(321).sample_all_variables([var], 8)

    expect(s1).to eq s2
    expect(s1).not_to eq s3
  end

  it 'raises for unknown distribution types' do
    var = make_var(name: 'bad_var', uncertainty_type: 'cauchy',
                   lower_bounds_value: 0, upper_bounds_value: 1, modes_value: 0.5)

    expect do
      described_class.new(1).sample_all_variables([var], 5)
    end.to raise_error(/not known for Ruby sampling/)
  end

  describe 'Variable.pivot_array without an R session' do
    it 'builds pivots from discrete values and Ruby integer sequences' do
      make_var(name: 'pivot_discrete', perturbable: false, pivot: true,
               uncertainty_type: 'discrete',
               discrete_values_and_weights: [{ 'value' => 'a' }, { 'value' => 'b' }])
      make_var(name: 'pivot_seq', perturbable: false, pivot: true,
               uncertainty_type: 'integer_sequence',
               lower_bounds_value: 1, upper_bounds_value: 3, modes_value: 1)

      pivots = Variable.pivot_array(@analysis.id)
      # cartesian product: 2 discrete x 3 sequence values
      expect(pivots.size).to eq 6
      pivots.each do |pivot|
        expect(pivot.values).to include(satisfy { |v| %w(a b).include?(v) })
        expect(pivot.values).to include(satisfy { |v| [1, 2, 3].include?(v) })
      end
    end
  end

  describe 'AnalysisLibrary::Lhs with the ruby backend' do
    it 'creates datapoints end to end without Rserve' do
      make_var(name: 'uniform_var', uncertainty_type: 'uniform',
               lower_bounds_value: 0.0, upper_bounds_value: 10.0, modes_value: 5.0)
      make_var(name: 'discrete_var', uncertainty_type: 'discrete',
               discrete_values_and_weights: [
                 { 'value' => 1, 'weight' => 0.5 },
                 { 'value' => 2, 'weight' => 0.5 }
               ])

      @analysis.problem['algorithm']['number_of_samples'] = 4
      @analysis.save!

      # no_delay: runs AnalysisLibrary::Lhs#perform inline. analysis_type is in
      # the options because the API path always posts it (core.rb keys the
      # analysis results hash off options[:analysis_type]).
      @analysis.run_analysis(true, 'lhs', 'analysis_type' => 'lhs')
      @analysis.reload

      # perform swallows exceptions into status_message; empty means clean run
      expect(@analysis.status_message.to_s).to eq ''

      dps = @analysis.data_points.to_a
      expect(dps.size).to eq 4
      var_ids = Variable.where(analysis_id: @analysis.id).map { |v| v.id.to_s }
      dps.each do |dp|
        expect(dp.status).to eq 'na'
        expect(dp.set_variable_values.keys).to match_array var_ids
      end
      expect(@analysis.jobs.last.status).to eq 'completed'
    end
  end
end
