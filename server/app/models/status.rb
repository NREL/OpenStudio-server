# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class Status
  include Mongoid::Document
  include Mongoid::Timestamps

  field :awake, type: DateTime
end
