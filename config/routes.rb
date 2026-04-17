Rails.application.routes.draw do
  root "static_pages#home"
  get "about", to: "static_pages#about"
  devise_for :users

  resources :products, only: [ :index, :show ]
  resources :categories, only: [ :show ]
  get "account", to: "accounts#show", as: :account

  get "up" => "rails/health#show", as: :rails_health_check
end
