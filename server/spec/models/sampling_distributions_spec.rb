# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe AnalysisLibrary::Sampling::Distributions do
  let(:d) { described_class }

  describe 'inverse_normal_cdf' do
    it 'returns 0 at the median' do
      expect(d.inverse_normal_cdf(0.5).abs).to be < 1e-12
    end

    it 'matches known quantiles' do
      expect(d.inverse_normal_cdf(0.975)).to be_within(1e-6).of(1.959964)
      expect(d.inverse_normal_cdf(0.025)).to be_within(1e-6).of(-1.959964)
      expect(d.inverse_normal_cdf(0.999)).to be_within(1e-6).of(3.090232)
      expect(d.inverse_normal_cdf(0.001)).to be_within(1e-6).of(-3.090232)
      # deep tail (exercises the rational-approximation tail branch)
      expect(d.inverse_normal_cdf(1e-10)).to be_within(1e-4).of(-6.361341)
    end

    it 'is antisymmetric' do
      [0.01, 0.2, 0.35, 0.75, 0.99].each do |p|
        expect(d.inverse_normal_cdf(p)).to be_within(1e-9).of(-d.inverse_normal_cdf(1.0 - p))
      end
    end

    it 'raises out of (0,1)' do
      expect { d.inverse_normal_cdf(0.0) }.to raise_error(/out of/)
      expect { d.inverse_normal_cdf(1.0) }.to raise_error(/out of/)
    end
  end

  describe 'q_uniform' do
    it 'maps 0/0.5/1 to min/mid/max' do
      expect(d.q_uniform(0.0, 2.0, 10.0)).to eq 2.0
      expect(d.q_uniform(0.5, 2.0, 10.0)).to eq 6.0
      expect(d.q_uniform(1.0, 2.0, 10.0)).to eq 10.0
    end
  end

  describe 'q_normal' do
    it 'shifts and scales the standard quantile' do
      expect(d.q_normal(0.5, 10.0, 2.0)).to be_within(1e-9).of(10.0)
      expect(d.q_normal(0.975, 10.0, 2.0)).to be_within(1e-5).of(10.0 + 2.0 * 1.959964)
    end
  end

  describe 'q_lognormal' do
    it 'replicates the R backend parameterization at the median' do
      mean = 10.0
      stddev = 4.0
      # mirror of r/lhs.rb: mu <- log((mean^2)/sqrt(stddev+mean^2)); median = exp(mu)
      expected_median = (mean**2) / Math.sqrt(stddev + mean**2)
      expect(d.q_lognormal(0.5, mean, stddev)).to be_within(1e-9).of(expected_median)
    end

    it 'is monotone increasing' do
      values = [0.1, 0.3, 0.5, 0.7, 0.9].map { |p| d.q_lognormal(p, 10.0, 4.0) }
      expect(values).to eq values.sort
    end
  end

  describe 'q_triangle' do
    it 'hits min, mode, and max' do
      expect(d.q_triangle(0.0, 0.0, 10.0, 5.0)).to eq 0.0
      expect(d.q_triangle(0.5, 0.0, 10.0, 5.0)).to be_within(1e-12).of(5.0)
      expect(d.q_triangle(1.0, 0.0, 10.0, 5.0)).to eq 10.0
    end

    it 'matches the closed form below the mode' do
      # p=0.125: min + sqrt(0.125 * 10 * 5) = 2.5
      expect(d.q_triangle(0.125, 0.0, 10.0, 5.0)).to be_within(1e-12).of(2.5)
    end

    it 'raises on invalid geometry' do
      expect { d.q_triangle(0.5, 0.0, 10.0, 12.0) }.to raise_error(/invalid triangle/)
    end
  end

  describe 'q_discrete' do
    let(:values) { %w(a b c) }
    let(:weights) { [2.0, 1.0, 1.0] } # unnormalized; cumulative = 0.5, 0.75, 1.0

    it 'returns the first value whose cumulative weight reaches p' do
      expect(d.q_discrete(0.1, weights, values)).to eq 'a'
      expect(d.q_discrete(0.5, weights, values)).to eq 'a'
      expect(d.q_discrete(0.6, weights, values)).to eq 'b'
      expect(d.q_discrete(0.75, weights, values)).to eq 'b'
      expect(d.q_discrete(0.76, weights, values)).to eq 'c'
      expect(d.q_discrete(1.0, weights, values)).to eq 'c'
    end

    it 'handles a single value' do
      expect(d.q_discrete(0.42, [1.0], [7])).to eq 7
    end

    it 'raises on bad input' do
      expect { d.q_discrete(0.5, [0.0, 0.0], [1, 2]) }.to raise_error(/sum to zero/)
      expect { d.q_discrete(0.5, [1.0], [1, 2]) }.to raise_error(/same length/)
      expect { d.q_discrete(0.5, [], []) }.to raise_error(/same length|no discrete/)
    end
  end

  describe 'seq' do
    it 'replicates R seq(from, to, by)' do
      expect(d.seq(1, 9, 2)).to eq [1.0, 3.0, 5.0, 7.0, 9.0]
      expect(d.seq(0, 1, 0.25)).to eq [0.0, 0.25, 0.5, 0.75, 1.0]
    end
  end

  describe 'lhs_probability' do
    it 'produces one point per stratum for every variable' do
      n = 10
      p = d.lhs_probability(3, n, Random.new(42))
      expect(p.keys).to eq [0, 1, 2]
      p.each_value do |col|
        expect(col.size).to eq n
        expect(col).to all(be >= 0.0)
        expect(col).to all(be < 1.0)
        strata = col.map { |v| (v * n).floor }.sort
        expect(strata).to eq (0...n).to_a
      end
    end

    it 'is deterministic for a given seed' do
      expect(d.lhs_probability(2, 5, Random.new(7))).to eq d.lhs_probability(2, 5, Random.new(7))
      expect(d.lhs_probability(2, 5, Random.new(7))).not_to eq d.lhs_probability(2, 5, Random.new(8))
    end
  end
end
