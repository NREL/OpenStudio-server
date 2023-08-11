# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class Algorithm
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :analysis
end
