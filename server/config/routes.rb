Rails.application.routes.draw do
  resources :paretos

  resources :data_points, only: [:index] do
    get :status, on: :collection
  end

  resources :analyses, only: [:index] do
    get :status, on: :collection
  end

  resources :compute_nodes

  resources :projects, shallow: true do
    member do
      get :status
    end

    resources :analyses, shallow: true do
      member do
        post :action
        post :upload
        get :stop
        get :status
        get :page_data
        get :analysis_data
        get :debug_log
        get :snow_log
        get :new_view
        get :plot_parallelcoordinates
        post :plot_parallelcoordinates
        get :plot_scatter
        get :plot_radar
        get :plot_bar
        get :download_data
        get :download_analysis_zip
        get :download_result_file
        get :download_seed_zip
        get :download_algorithm_results_zip
        get :dencity
        get :download_selected_datapoints

        get :plot_xy_interactive
        post :plot_xy_interactive
      end

      collection do
        get :status
      end

      resources :measures, only: [:show, :index], shallow: true
      resources :paretos, only: [:show, :index, :edit, :update], shallow: true
      resources :variables, only: [:show, :index, :edit, :update], shallow: true do
        collection do
          get :download_metadata
          get :download_variables
          get :metadata

          get :modify
          post :modify
        end
      end

      resources :data_points, shallow: true do
        member do
          get :view_report
          # get :download_reports # TODO: Remove this
          get :dencity

          # Download reports
          post :download_report

          # download a result file
          get :download_result_file

          # TODO: Review the end points
          put :run
          post :upload_file
          delete :result_files
        end

        collection do
          post :batch_upload
        end
      end
    end
    # end
  end

  resources :admin, only: [:index] do
    collection do
      get :backup_database
      post :restore_database
    end
  end

  match '/about', to: 'pages#about', via: :get
  match '/status', to: 'pages#status', via: :get

  root to: 'pages#dashboard'

  # Always provide this for debugging, at least to start with. Redact the link in case of production runs
  require "resque_web"
  mount ResqueWeb::Engine => "/resque"
end
