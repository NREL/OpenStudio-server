require 'spec_helper'

describe 'worker-init' do
  it 'should sort worker jobs correctly' do
    a = %w(00_Job0 01_Job1 11_Job11 20_Job20 02_Job2 21_Job21)

    a.sort!

    expect(a.first).to eq '00_Job0'
    expect(a.last).to eq '21_Job21'
    expect(a[3]).to eq '11_Job11'
  end
end
