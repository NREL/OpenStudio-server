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

require 'spec_helper'

describe Analysis::SequentialSearch do
  before :all do
    # need to populate the database with an analysis and datapoints

    # delete all the analyses
    # parameter_space[SecureRandom.uuid] = {id: SecureRandom.uuid, measure_id: measure._id, variables: mvs}
    @ps = {}
    @ps['1'] = { id: '1', measure_id: 'roof', variables: { 'r_value' => 5 } }
    @ps['2'] = { id: '2', measure_id: 'roof', variables: { 'r_value' => 70, 'cool' => true } }
    @ps['3'] = { id: '3', measure_id: 'hvac', variables: { 'efficiency' => 1.2 } }
    @ps['4'] = { id: '4', measure_id: 'hvac', variables: { 'efficiency' => 2.5 } }
    @ps['5'] = { id: '5', measure_id: 'hvac', variables: { 'efficiency' => 3.5 } }
    @ps['6'] = { id: '6', measure_id: 'hvac', variables: { 'efficiency' => 4 } }
    @ps['7'] = { id: '7', measure_id: 'lpd', variables: { 'reduction' => 30 } }
  end

  it 'should have 3 parameters' do
    @ps.size.should eq(7)
  end

  it 'should return all the datapoints' do
    vgl_ids = []

    # get the full ps information
    vgls = @ps.select { |k, v| v if vgl_ids.include?(k) }

    vgls.size.should eq(0)

    run_list = Analysis::SequentialSearch.mash_up_hash(vgls, @ps)

    puts "Run list was returned with #{run_list.inspect}"
    puts "run list of size of #{run_list.size} is #{run_list}"
    run_list.size.should eq(7) # 7 because it has itself
    run_list.should eq([['1'], ['2'], ['3'], ['4'], ['5'], ['6'], ['7']])

    # now create the run list data
    data_point_list = Analysis::SequentialSearch.create_data_point_list(@ps, run_list, 1)
    data_point_list.size.should eq(7)
    data_point_list.first[:variables].should_not be_nil
    data_point_list.first[:name].should_not be_nil
  end

  it "if 'vgl=1' then result should be ?" do
    vgl_ids = ['1']

    # get the full ps information
    vgls = @ps.select { |k, v| v if vgl_ids.include?(k) }

    vgls.size.should_not eq(0)

    run_list = Analysis::SequentialSearch.mash_up_hash(vgls, @ps)

    puts "Run list was returned with #{run_list.inspect}"
    puts "run list of size of #{run_list.size} is #{run_list}"
    run_list.size.should eq(7) # 7 because it has itself
    run_list.should eq([['1'], ['2'], %w(1 3), %w(1 4), %w(1 5), %w(1 6), %w(1 7)])

    # now create the run list data
    data_point_list = Analysis::SequentialSearch.create_data_point_list(@ps, run_list, 1)
    data_point_list.size.should eq(7)
    data_point_list.first[:variables].should_not be_nil
    data_point_list.first[:name].should_not be_nil
  end

  it "if 'vgl=1' then result should be ?" do
    vgl_ids = %w(1 3)

    # get the full ps information
    vgls = @ps.select { |k, v| v if vgl_ids.include?(k) }

    run_list = Analysis::SequentialSearch.mash_up_hash(vgls, @ps)

    puts "run list of size of #{run_list.size} is #{run_list.uniq}"
    run_list.size.should eq(6) # only six for now because we aren't pulling out the values
    run_list.should eq([%w(1 3), %w(2 3), %w(1 4), %w(1 5), %w(1 6), %w(1 3 7)])

    # now create the run list data
    data_point_list = Analysis::SequentialSearch.create_data_point_list(@ps, run_list, 1)
    data_point_list.size.should eq(6)
    data_point_list.first[:variables].should_not be_nil
    data_point_list.first[:variables].size.should eq(2)
    data_point_list.first[:name].should_not be_nil
  end
end
