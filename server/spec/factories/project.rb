FactoryGirl.define do
  factory :data_point do
    name "Example Data Point"
    analysis
  end

  factory :analysis do
    name "Example Analysis"
    project

    factory :analysis_with_data_points do
      ignore do
        data_point_count 1
      end

      after(:create) do |analysis, evaluator|
        FactoryGirl.create_list(:data_point, evaluator.data_point_count, analysis: analysis)
      end
    end
  end

  factory :project do
    name "Test Project"

    factory :project_with_analyses do
      ignore do
        analyses_count 1
      end

      after(:create) do |project, evaluator|
        FactoryGirl.create_list(:analysis_with_data_points, evaluator.analyses_count, project: project)
      end
    end
  end
end
