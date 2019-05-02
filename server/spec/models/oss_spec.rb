# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
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

require 'rails_helper'

# Tag this as depending on resque because the test script does not run on windows.
RSpec.describe Utility::Oss, type: :model, depends_resque: true do
  context 'arguments' do
    before do
      @example_arg = { arg_1: 525600, arg_2: 'string', arg_3: 3.14 }
    end

    it 'does not load incorrect arguments' do
      tempfile = Tempfile.new('wrong_arguments.txt')
      tempfile.write(JSON.pretty_generate(@example_arg))
      tempfile.close
      args = Utility::Oss.load_args tempfile.path
      expect(args).to eq nil
      tempfile.unlink
    end

    it 'loads correct arguments' do
      tempfile = Tempfile.new('right_arguments.txt')
      tempfile.write(@example_arg.values)
      tempfile.close

      # with tempfile
      args = Utility::Oss.load_args tempfile.path
      expect(args).to eq [525600, 'string', 3.14]
      tempfile.unlink
    end
  end

  context 'run_script' do
    before do
      @log_file = File.expand_path('oss_spec.log', File.dirname(__FILE__))
      @example_script = 'echo "successfully ran"'
    end

    after do
      File.delete(@log_file) if File.exist? @log_file
    end

    it 'run_scripts with no arguments' do
      tempfile = Tempfile.new('script.sh')
      tempfile.write(@example_script)
      tempfile.close

      # Log file must be passes otherwise the Utility::Oss.run_script errors with
      result = Utility::Oss.run_script(tempfile.path, 4.hours, {}, nil, Logger.new(STDOUT), @log_file)

      result_log = File.read(@log_file).chomp
      puts result_log
      expect(result_log).to eq 'successfully ran'

      expect(result).to eq true
      expect(File.exist?(@log_file)).to eq true

      result_log = File.read(@log_file).chomp
      expect(result_log).to eq 'successfully ran'

      tempfile.unlink
    end

    it 'sets only some env vars' do
      ENV['BUNDLE_POINTLESS'] = 'Affirmative'
      env_vars = Utility::Oss.resolve_env_vars('my_custom_env' => 'set_to_this_value')
      expect(env_vars.key?('my_custom_env')).to eq true
      expect(env_vars.key?('USER')).to eq false
      expect(env_vars['BUNDLE_POINTLESS']).to eq 'Affirmative'
    end
  end
end
