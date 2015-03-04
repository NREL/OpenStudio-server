OpenstudioServer::Application.routes.draw do
  resources :paretos

  resources :data_points, only: [:index] do
    get :status, on: :collection
  end

  resources :analyses, only: [:index] do
    get :status, on: :collection
  end

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
        get :plot_scatter
        get :plot_radar
        get :plot_bar
        get :download_data
        get :dencity

        match 'plot_parallelcoordinates' => 'analyses#plot_parallelcoordinates', :via => [:get, :post]
        match 'plot_xy_interactive' => 'analyses#plot_xy_interactive', :via => [:get, :post]
      end

      resources :measures, only: [:show, :index], shallow: true
      resources :paretos, only: [:show, :index, :edit, :update], shallow: true
      resources :variables, only: [:show, :index, :edit, :update], shallow: true do
        collection do
          get :download_metadata
          get :download_variables
          get :metadata
          match 'modify' => 'variables#modify', :via => [:get, :post]
        end
      end

      resources :data_points, shallow: true  do
        member do
          get :show_full # 10/22/14 - Need to deprecate this, only historic analysis stuff uses this
          get :view_report
          get :download
          get :download_reports
          get :dencity
        end

        collection do
          post :batch_upload
        end
      end
    end
    # end
  end

  match 'admin/backup_database' => 'admin#backup_database', :via => :get
  match 'admin/restore_database' => 'admin#restore_database', :via => :post
  match 'admin/clear_database' => 'admin#clear_database', :via => :get

  resources :admin, only: [:index] do
    get :backup_database
    post :restore_database
    get :clear_database
  end

  match '/about' => 'pages#about'
  match '/analyses' => 'analyses#index'
  match '/status' => 'pages#status'

  # DEnCity routes
  match 'metadata' => 'variables#metadata', :via => :get
  match 'download_metadata' => 'variables#download_metadata', :via => :get

  root to: 'pages#dashboard'
end
