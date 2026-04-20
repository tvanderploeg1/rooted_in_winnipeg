Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  root "static_pages#home"
  get "about", to: "static_pages#about"
  devise_for :users

  resources :products, only: [ :index, :show ]
  resources :categories, only: [ :show ]
  resources :orders, only: [ :index, :show, :new, :create ] do
    post :start_payment, on: :member
    get :payment, on: :member
  end
  resource :cart, only: [ :show ]
  resources :cart_items, only: [ :create, :destroy, :update ]
  get "checkout", to: "orders#new", as: :checkout
  get "account", to: "accounts#show", as: :account
  post "stripe/webhook", to: "stripe_webhooks#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
