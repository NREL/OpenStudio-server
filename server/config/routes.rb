Rails.application.routes.draw do
  resources :paretos

  resources :data_points, only: [:index] do
    get :status, on: :collection
  end

  resources :analyses, only: [:index] do
    get :status, on: :collection
  end

  resources :compute_nodes, only: [:index]

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
        get :download_status
        get :debug_log
        get :new_view
        get :plot_parallelcoordinates
        post :plot_parallelcoordinates
        get :plot_scatter
        get :plot_radar
        get :plot_bar
        get :download_data
        get :download_analysis_zip
        get :download_algorithm_results_zip
        get :dencity

        get :plot_xy_interactive
        post :plot_xy_interactive
      end

      resources :measures, only: [:show, :index], shallow: true
      resources :paretos, only: [:show, :index, :edit, :update], shallow: true
      resources :variables, only: [:show, :index, :edit, :update], shallow: true do
        collection do
          get :download_metadata
          get :download_variables
          get :metadata

          # TODO: fix this route
          # match 'modify' => 'variables#modify', :via => [:get, :post]
        end
      end

      resources :data_points, shallow: true do
        member do
          get :show_full # TODO: 10/22/14 - Need to deprecate this, only historic analysis stuff uses this
          get :view_report
          get :download
          get :download_reports
          get :dencity

          # TODO: Review the end points
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

  # match '/nodes' => 'pages#nodes'

  # DEnCity routes
  # match 'metadata' => 'variables#metadata', :via => :get
  # match 'download_metadata' => 'variables#download_metadata', :via => :get

  root to: 'pages#dashboard'
end
