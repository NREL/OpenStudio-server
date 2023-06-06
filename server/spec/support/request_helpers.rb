# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# spec/support/request_helpers.rb
module Requests
  module JsonHelpers
    def json
      JSON.parse(response.body)
    end
  end
end
