Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "dashboard#index"
  resources :reservations, only: [ :index, :new, :create ]

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

  namespace :api do
    resources :reservations, only: %i[index create destroy]

    # ユーザー情報
    get "users/me", to: "users#me"
    get "users", to: "users#index"
    get "users/:id", to: "users#show"
    post "users", to: "users#create"
    put "users/:id", to: "users#update"
    delete "users/:id", to: "users#destroy"
    delete "users/logout", to: "users#logout"
  end

  if Rails.env.test?
    post "/test/login", to: "test_session#create"
  end
end
