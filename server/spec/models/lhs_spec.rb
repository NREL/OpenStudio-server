# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'rails_helper'

RSpec.describe AnalysisLibrary::Lhs, type: :model do
  before do
    # need to populate the database with an analysis and datapoints

    # delete all the analyses

    analysis_id = 'abcd'
    @lhs = AnalysisLibrary::Lhs.new(analysis_id, {})

    @pivots = [{ p1: 'p1' }, { p1: 'p2' }]
    @samples = [{ a: 1, b: 2 }, { a: 3, b: 4 }, { e: 5 }]
    @statics = [{ s1: 'a' }, { s2: true }]
  end

  it 'has the right sizes' do
    expect(@pivots.size).to eq 2
    expect(@samples.size).to eq 3
    expect(@statics.size).to eq 2
  end

  it 'static result should return the same length' do
    result = @lhs.add_static_variables(@samples, @statics)
    puts "Static hash returned with #{result.inspect}"

    expect(result.size).to eq 3
    expect(result[0]).to eq(a: 1, b: 2, s1: 'a', s2: true)
  end

  it 'pivot result should have double the length' do
    result = @lhs.add_pivots(@samples, @pivots)
    puts "Pivot hash returned with #{result.inspect}"

    expect(result.size).to eq(6)
    expect(result[0]).to eq(p1: 'p1', a: 1, b: 2)
  end
end
