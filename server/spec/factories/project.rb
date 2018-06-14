# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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

FactoryBot.define do
  factory :data_point do
    name 'Example Datapoint'
    analysis

    json = JSON.parse(File.read("#{Rails.root}/spec/files/batch_datapoints/example_data_point_1.json"))
    initialize_with { new(json) }
  end

  factory :analysis do
    name 'Example Analysis'
    project

    json = JSON.parse(File.read("#{Rails.root}/spec/files/batch_datapoints/example_csv.json"))

    initialize_with { new(json['analysis']) }

    seed_zip { File.new("#{Rails.root}/spec/files/batch_datapoints/example_csv.zip") }

    factory :analysis_with_data_points do
      transient do
        data_point_count 200
      end

      after(:create) do |analysis, evaluator|
        FactoryBot.create_list(
          :data_point, evaluator.data_point_count,
          status: 'completed',
          status_message: 'completed normal',
          analysis: analysis
        )
      end
    end
  end

  factory :project do
    name 'Test Project'

    factory :project_with_analyses do
      transient do
        analyses_count 1
      end

      after(:create) do |project, evaluator|
        FactoryBot.create_list(:analysis_with_data_points, evaluator.analyses_count, project: project)
      end
    end
  end
end
