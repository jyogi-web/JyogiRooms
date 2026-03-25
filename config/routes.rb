Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "dashboard#index"
  resources :reservations, except: [ :show ]
  resources :keys, only: [ :index ]

  resources :rooms, only: [] do
    resource :key, only: [] do
      get :transfer_form
      post :transfer
      get :assign_form
      post :assign
      post :unassign
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # jyogi-auth OAuth2認証
  get "auth/login", to: "auth#login"
  get "auth/callback", to: "auth#callback"
  delete "auth/logout", to: "auth#logout"
  get "auth/logged_out", to: "auth#logged_out"

  namespace :api do
    resources :reservations, only: %i[index create destroy]
    resources :keys, only: %i[index]

    # ユーザー情報
    get "users/me", to: "users#me"
    resources :users, only: %i[index show create update destroy]
  end

  # 管理者画面
  namespace :admin do
    root "roles#index"
    resources :roles, only: %i[index show update]
    resources :users, only: %i[show update]
    resources :key_transfer_logs, only: %i[index show]
    resource :scheduled_announcement, only: %i[edit update]
  end

  if Rails.env.test?
    post "/test/login", to: "test_session#create"
  end
end
