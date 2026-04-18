Rails.application.routes.draw do
  root "static_pages#home"
  get "about", to: "static_pages#about"
  devise_for :users

  resources :products, only: [ :index, :show ]
  resources :categories, only: [ :show ]
  resources :orders, only: [ :index, :show, :new ]
  resource :cart, only: [ :show ]
  resources :cart_items, only: [ :create, :destroy, :update ]
  get "checkout", to: "orders#new", as: :checkout
  get "account", to: "accounts#show", as: :account

  get "up" => "rails/health#show", as: :rails_health_check
end
