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

RSpec.describe AnalysisLibrary::Lhs, type: :model do
  before :each do
    # need to populate the database with an analysis and datapoints

    # delete all the analyses

    analysis_id = 'abcd'
    @lhs = AnalysisLibrary::Lhs.new(analysis_id, {})

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
