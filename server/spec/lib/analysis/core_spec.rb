require 'spec_helper'

describe Analysis::Core do
  class DummyClass
  end

  before :each do
    @dummy_class = DummyClass.new
    @dummy_class.extend(Analysis::Core)

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

  it 'should have the right sizes' do
    @pivots.size.should eq(2)
    @samples.size.should eq(3)
    @statics.size.should eq(2)
  end

  context 'pivot variables' do
    it 'pivot result should have double the length' do
      result = @dummy_class.add_pivots(@samples, @pivots)
      puts "Pivot hash returned with #{result.inspect}"

      result.size.should eq(6)
      result[0].should eq(p1: 'p1', a: 1, b: 2)
    end

    it 'should return the same back when pivots is empty' do
      result = @dummy_class.add_pivots(@samples, [])

      result.size.should eq(3)
      result.should eq(@samples)
    end
  end

  context 'static variables' do
    it 'static result should return the same length' do
      result = @dummy_class.add_static_variables(@samples, @statics)
      puts "Static hash returned with #{result.inspect}"

      result.size.should eq(3)
      result[0].should eq(a: 1, b: 2, s1: 'a', s2: true)
    end

    it 'should return back the same objects if statics are empty' do
      result = @dummy_class.add_pivots(@samples, [])

      result.size.should eq(3)
      result.should eq(@samples)
    end

  end

  context 'hashing' do
    it 'should return array of hashes' do
      h = { a: [1, 2, 3], b: [4, 5, 6] }
      r = Analysis::Core.hash_of_array_to_array_of_hash(h)
      r.size.should eq(h[:a].size)
      r[0].should eq(a: 1, b: 4)
    end

    it 'should not work when array length is different' do
      h = { a: [1, 2, 3], b: [4, 5, 6, 7, 8, 9] }
      expect { Analysis::Core.hash_of_array_to_array_of_hash(h) }.to raise_error
    end

    it 'should work with any type of data' do
      h = { a: [1, 2, 3], b: %w(4 5 6), c: [true, false, false] }
      r = Analysis::Core.hash_of_array_to_array_of_hash(h)
      r.size.should eq(h[:a].size)
      r[0].should eq(a: 1, b: '4', c: true)
    end

    it 'should return non-combined hashes' do
      h = { a: [1, 2, 3], b: %w(4 5 6), c: [true, false, false] }
      vars = [OpenStruct.new(_id: 'c', static_value: 123)]
      r = Analysis::Core.hash_of_array_to_array_of_hash_non_combined(h, vars)
      puts "Non combined hash returned with #{r.inspect}"
      r.size.should eq(8)
      r[0].should eq(a: 1, c: 123)
      r[5].should eq(b: '6', c: 123)
      r[6].should eq(c: true)
      r[7].should eq(c: false)
    end

  end
end
