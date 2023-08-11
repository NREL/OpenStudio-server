# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

FactoryBot.define do
  factory :compute_node do
    node_type { 'server' }
    ip_address { 'localhost' }
    hostname { 'os-server' }
    cores { '2' }
    enabled { true }
  end
end
