# spec/support/request_helpers.rb
module Requests
  module JsonHelpers
    def json
      JSON.parse(response.body)
    end
  end
end