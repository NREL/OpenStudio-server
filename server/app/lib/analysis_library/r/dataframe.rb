# *******************************************************************************
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
# *******************************************************************************

module AnalysisLibrary
  module R
    class DataFrame
      def self.save_dataframe(hash, dataframe_name, savepath)
        FileUtils.rm(savepath) if File.exist?(savepath)

        # force directory
        dir = File.expand_path(File.dirname(savepath))
        FileUtils.mkdir_p(dir)
        filename = File.basename(savepath)

        r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                    APP_CONFIG['rserve_port'])
        r.command "setwd('#{File.expand_path(dir)}')"

        save_string = "save('#{dataframe_name}', file = '#{dir}/#{filename}')"
        r.converse(save_string, dataframe_name.to_sym => hash.to_dataframe)
      end

      def self.generate_summaries(dataframe)
        r = AnalysisLibrary::Core.initialize_rserve(APP_CONFIG['rserve_hostname'],
                                                    APP_CONFIG['rserve_port'])
        result = r.converse('summary(df)', df: dataframe)
        result = result.each_slice(6).to_a

        hash = OrderedHash.new
        dataframe.colnames.each_index do |i|
          hash[dataframe.colnames[i]] = { raw: result[i].each { |v| v.strip! unless v.nil? } }
        end

        # now clean up the names
        hash.each_key do |key|
          hash[key][:raw].each do |v|
            if v =~ /^Min./
              hash[key][:min] = v.split(':')[1].to_f
            elsif v =~ /^1st Qu./
              hash[key][:first_q] = v.split(':')[1].to_f
            elsif v =~ /^Median./
              hash[key][:median] = v.split(':')[1].to_f
            elsif v =~ /Mean./
              hash[key][:mean] = v.split(':')[1].to_f
            elsif v =~ /3rd Qu./
              hash[key][:third_q] = v.split(':')[1].to_f
            elsif v =~ /Max./
              hash[key][:max] = v.split(':')[1].to_f
            end
          end
        end

        hash
      end
    end
  end
end
