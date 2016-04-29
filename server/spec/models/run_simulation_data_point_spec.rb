require 'rails_helper'

RSpec.describe RunSimulateDataPoint, type: :model do
  it 'should run the data point' do
    a = RunSimulateDataPoint.new
    a.perform.delay

    puts Delayed::Job.count

    # expect(Delayed::Job.count).to eq(1)
  end
end
