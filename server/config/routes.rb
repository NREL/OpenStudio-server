OpenstudioServer::Application.routes.draw do
  resources :paretos


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
          get :show_full
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

  # DenCity routes
  match 'metadata' => 'variables#metadata', :via => :get
  match 'download_metadata' => 'variables#download_metadata', :via => :get

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root to: 'pages#dashboard'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
