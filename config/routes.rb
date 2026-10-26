Rails.application.routes.draw do
  root "dashboard#index"

  resources :syncs, only: [:index, :show]
  resources :received_files, only: :index
  resource :config, only: [:edit, :update]

  namespace :sender do
    resources :payloads, only: :index
  end

  namespace :receiver do
    resources :payloads, only: :index
  end

  mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
end
