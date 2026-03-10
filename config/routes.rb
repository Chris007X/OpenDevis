Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  resources :projects do
    resources :rooms, only: [:index, :new, :create]
    resources :documents, only: [:index, :new, :create]
  end

  resources :rooms, only: [:show, :edit, :update, :destroy] do
    resources :work_items, only: [:new, :create]
  end

  resources :work_items, only: [:edit, :update, :destroy]
  resources :documents, only: [:destroy]

  resources :work_categories, only: [:index, :show]
  resources :materials, only: [:index, :show]

  get "up" => "rails/health#show", as: :rails_health_check
end
