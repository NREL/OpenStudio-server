# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

FactoryBot.define do
  factory :data_point do
    name { 'Example Datapoint' }
    analysis

    json = JSON.parse(File.read("#{Rails.root}/spec/files/batch_datapoints/example_data_point_1.json"))
    initialize_with { new(json) }
  end

  factory :analysis do
    name { 'Example Analysis' }
    project

    json = JSON.parse(File.read("#{Rails.root}/spec/files/batch_datapoints/example_csv.json"))

    initialize_with { new(json['analysis']) }

    seed_zip { File.new("#{Rails.root}/spec/files/batch_datapoints/example_csv.zip") }

    factory :analysis_with_data_points do
      transient do
        data_point_count { 200 }
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
    name { 'Test Project' }

    factory :project_with_analyses do
      transient do
        analyses_count { 1 }
      end

      after(:create) do |project, evaluator|
        FactoryBot.create_list(:analysis_with_data_points, evaluator.analyses_count, project: project)
      end
    end
  end
end
