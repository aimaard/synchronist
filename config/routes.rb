Rails.application.routes.draw do
  root "dashboard#index"

  # Health check for Docker (no authentication)
  get "up" => "rails/health#show", as: :rails_health_check

  resources :syncs, only: [:index, :show]
  resources :received_files, only: :index
  resource :config, only: :show

  namespace :sender do
    resources :payloads, only: :index
  end

  namespace :receiver do
    resources :payloads, only: :index
  end

  mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
end
