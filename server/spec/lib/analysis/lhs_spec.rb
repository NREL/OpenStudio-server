require 'spec_helper'

describe Analysis::Lhs do
  before :each do
    # need to populate the database with an analysis and datapoints

    # delete all the analyses

    analysis_id = 'abcd'
    @lhs = Analysis::Lhs.new(analysis_id, {})

    @pivots = [{ p1: 'p1' }, { p1: 'p2' }]
    @samples = [{ a: 1, b: 2 }, { a: 3, b: 4 }, { e: 5 }]
    @statics = [{ s1: 'a' }, { s2: true }]
  end

  it 'should have the right sizes' do
    @pivots.size.should eq(2)
    @samples.size.should eq(3)
    @statics.size.should eq(2)
  end

  it 'static result should return the same length' do
    result = @lhs.add_static_variables(@samples, @statics)
    puts "Static hash returned with #{result.inspect}"

    result.size.should eq(3)
    result[0].should eq(a: 1, b: 2, s1: 'a', s2: true)
  end

  it 'pivot result should have double the length' do
    result = @lhs.add_pivots(@samples, @pivots)
    puts "Pivot hash returned with #{result.inspect}"

    result.size.should eq(6)
    result[0].should eq(p1: 'p1', a: 1, b: 2)
  end
end
