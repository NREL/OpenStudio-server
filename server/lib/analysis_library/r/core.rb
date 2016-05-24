# Include these gems/libraries for all the analyses
require 'rserve/simpler'

# Core functions for analysis
module AnalysisLibrary
  module R
    module Core
      def initialize_rserve(hostname='localhost', port=6311)
        rserve_options = {
            hostname: hostname,
            port_number: port
        }
        Rserve::Simpler.new(rserve_options)
      end

      module_function :initialize_rserve
    end
  end
end
