Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "dashboard#index"
  resources :reservations, except: [ :show ] do
    collection do
      get :show_date
    end
  end
  resources :keys, only: [ :index ]
  resources :nfc_cards, only: %i[index destroy]
  post "admin_disguise/toggle", to: "admin_disguise#toggle", as: :toggle_admin_disguise
  get "stats/ranking", to: "stats#ranking", as: :stats_ranking
  get "stats/me", to: "stats#me", as: :stats_me
  resources :room_statuses, only: %i[index] do
    member do
      post :exit_room
      post :close_room
    end
    collection do
      get :logs
    end
  end

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

    # 部室API
    resources :rooms, only: [] do
      post :touch, to: "rooms/touches#create"
      post :enter, to: "rooms/entries#enter"
      post :exit, to: "rooms/entries#exit"
      post :open, to: "rooms/states#open"
      post :close, to: "rooms/states#close"
      get :status, to: "rooms/statuses#show"
    end

    # 統計
    get "stats/ranking", to: "stats#ranking"
    get "stats/me", to: "stats#me"

    # NFC登録
    resources :nfc_registrations, only: %i[create show destroy] do
      member do
        patch :confirm
      end
    end
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
