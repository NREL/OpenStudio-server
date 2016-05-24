#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#*******************************************************************************

require 'rails_helper'

RSpec.describe AnalysisLibrary::Core, type: :model do
  class DummyClass
  end

  before :each do
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

  it 'should have the right sizes' do
    @pivots.size.should eq(2)
    @samples.size.should eq(3)
    @statics.size.should eq(2)
  end

  context 'pivot variables' do
    it 'pivot result should have double the length' do
      result = @dummy_class.add_pivots(@samples, @pivots)
      # puts "Pivot hash returned with #{result.inspect}"

      result.size.should eq(6)
      result[0].should eq(p1: 'p1', a: 1, b: 2)
    end

    it 'should return the same back when pivots is empty' do
      result = @dummy_class.add_pivots(@samples, [])

      result.size.should eq(3)
      result.should eq(@samples)
    end

    it 'should return no pivots when the pivot array is empty' do
      result = AnalysisLibrary::Core.product_hash([])

      result.should eq([])
    end

    it 'should deal with more than two piviots' do
      result = AnalysisLibrary::Core.product_hash(a: [1, 2], b: [3, 4], c: [5, 6])

      result.size.should eq(8)
    end

    it 'should deal with non-integers' do
      result = AnalysisLibrary::Core.product_hash(a: [1.23, 4.56], b: [true, false], c: %w(p q))

      result.size.should eq(8)
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
      r = AnalysisLibrary::Core.hash_of_array_to_array_of_hash(h)
      r.size.should eq(h[:a].size)
      r[0].should eq(a: 1, b: 4)
    end

    it 'should not work when array length is different' do
      h = { a: [1, 2, 3], b: [4, 5, 6, 7, 8, 9] }
      expect { AnalysisLibrary::Core.hash_of_array_to_array_of_hash(h) }.to raise_error(IndexError)
    end

    it 'should work with any type of data' do
      h = { a: [1, 2, 3], b: %w(4 5 6), c: [true, false, false] }
      r = AnalysisLibrary::Core.hash_of_array_to_array_of_hash(h)
      r.size.should eq(h[:a].size)
      r[0].should eq(a: 1, b: '4', c: true)
    end

    it 'should return non-combined hashes' do
      h = { a: [1, 2, 3], b: %w(4 5 6), c: [true, false, false] }
      vars = [OpenStruct.new(_id: 'c', static_value: 123)]
      r = AnalysisLibrary::Core.hash_of_array_to_array_of_hash_non_combined(h, vars)
      puts "Non combined hash returned with #{r.inspect}"
      r.size.should eq(8)
      r[0].should eq(a: 1, c: 123)
      r[5].should eq(b: '6', c: 123)
      r[6].should eq(c: true)
      r[7].should eq(c: false)
    end
  end
end
