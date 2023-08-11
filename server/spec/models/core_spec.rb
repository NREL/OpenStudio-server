# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe AnalysisLibrary::Core, type: :model do
  class DummyClass
  end

  before do
    @dummy_class = DummyClass.new
    @dummy_class.extend(AnalysisLibrary::Core)

    # need to populate the database with an analysis and datapoints

    # delete all the analyses

    # take static = [{a: 1, b: 2}]
    # with samples = [{c: 3}, {d: 4}]
    # results is [{a:1, b:2, c:3}, {a:1, b:2, d:4}]

    # take p = [{p1: 1}, {p1: 2}]
    # with s = [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    # make s' = [{p1: 1, a: 1, b: 4}, {p1: 2, a: 1, b: 4}, {p1: 1, a: 2, b: 5},  {p1: 2, a: 2, b: 5}]
    @pivots = [{ p1: 'p1' }, { p1: 'p2' }]
    @samples = [{ a: 1, b: 2 }, { a: 3, b: 4 }, { e: 5 }]
    @statics = [{ s1: 'a' }, { s2: true }]

    # take p = [{p1: 1}, {p1: 2}]
    # with s = [{a: 1, b: 4}, {a: 2, b: 5}, {a: 3, b: 6}]
    # make s' = [{p1: 1, a: 1, b: 4}, {p1: 2, a: 1, b: 4}, {p1: 1, a: 2, b: 5},  {p1: 2, a: 2, b: 5}]
    @pivots = [{ p1: 'p1' }, { p1: 'p2' }]
    @samples = [{ a: 1, b: 2 }, { a: 3, b: 4 }, { e: 5 }]
    @statics = [{ s1: 'a' }, { s2: true }]
  end

  it 'has the right sizes' do
    expect(@pivots.size).to eq(2)
    expect(@samples.size).to eq(3)
    expect(@statics.size).to eq(2)
  end

  context 'pivot variables' do
    it 'pivot result should have double the length' do
      result = @dummy_class.add_pivots(@samples, @pivots)
      # puts "Pivot hash returned with #{result.inspect}"

      expect(result.size).to eq(6)
      expect(result[0]).to eq(p1: 'p1', a: 1, b: 2)
    end

    it 'returns the same back when pivots is empty' do
      result = @dummy_class.add_pivots(@samples, [])

      expect(result.size).to eq(3)
      expect(result).to eq(@samples)
    end

    it 'returns no pivots when the pivot array is empty' do
      result = AnalysisLibrary::Core.product_hash([])

      expect(result).to eq []
    end

    it 'deals with more than two piviots' do
      result = AnalysisLibrary::Core.product_hash(a: [1, 2], b: [3, 4], c: [5, 6])

      expect(result.size).to eq(8)
    end

    it 'deals with non-integers' do
      result = AnalysisLibrary::Core.product_hash(a: [1.23, 4.56], b: [true, false], c: ['p', 'q'])

      expect(result.size).to eq 8
    end
  end

  context 'static variables' do
    it 'static result should return the same length' do
      result = @dummy_class.add_static_variables(@samples, @statics)
      puts "Static hash returned with #{result.inspect}"

      expect(result.size).to eq 3
      expect(result[0]).to eq(a: 1, b: 2, s1: 'a', s2: true)
    end

    it 'returns back the same objects if statics are empty' do
      result = @dummy_class.add_pivots(@samples, [])

      expect(result.size).to eq 3
      expect(result).to eq(@samples)
    end
  end

  context 'hashing' do
    it 'returns array of hashes' do
      h = { a: [1, 2, 3], b: [4, 5, 6] }
      r = AnalysisLibrary::Core.hash_of_array_to_array_of_hash(h)
      expect(r.size).to eq h[:a].size
      expect(r[0]).to eq(a: 1, b: 4)
    end

    it 'does not work when array length is different' do
      h = { a: [1, 2, 3], b: [4, 5, 6, 7, 8, 9] }
      expect { AnalysisLibrary::Core.hash_of_array_to_array_of_hash(h) }.to raise_error(IndexError)
    end

    it 'works with any type of data' do
      h = { a: [1, 2, 3], b: ['4', '5', '6'], c: [true, false, false] }
      r = AnalysisLibrary::Core.hash_of_array_to_array_of_hash(h)
      expect(r.size).to eq h[:a].size
      expect(r[0]).to eq(a: 1, b: '4', c: true)
    end

    it 'returns non-combined hashes' do
      h = { a: [1, 2, 3], b: ['4', '5', '6'], c: [true, false, false] }
      vars = [OpenStruct.new(_id: 'c', static_value: 123)]
      r = AnalysisLibrary::Core.hash_of_array_to_array_of_hash_non_combined(h, vars)
      puts "Non combined hash returned with #{r.inspect}"
      expect(r.size).to eq 8
      expect(r[0]).to eq(a: 1, c: 123)
      expect(r[5]).to eq(b: '6', c: 123)
      expect(r[6]).to eq(c: true)
      expect(r[7]).to eq(c: false)
    end
  end
end
