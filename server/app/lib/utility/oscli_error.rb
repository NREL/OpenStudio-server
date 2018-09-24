module Utility
  class OscliError < StandardError
    def initialize(oscli_err_r)
      msg = "Error running OpenStudio CLI: " + oscli_err_r.read
      super(msg)
    end
  end
end