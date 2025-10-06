Rails.application.routes.draw do
  # API-only Devise routes - skip sessions controller
  devise_for :users, skip: [:sessions]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Action Cable WebSocket endpoint
  mount ActionCable.server => "/cable"

  # API routes
  namespace :api do
    namespace :v1 do
      resources :notes do
        member do
          post :fork
        end

        resources :versions do
          member do
            post :revert
          end
        end

        resources :collaborators, only: [:index, :create, :destroy]
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
