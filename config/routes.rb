Rails.application.routes.draw do
  devise_for :users
  devise_for :artisans, path: "artisans", controllers: { sessions: "artisans/sessions" }
  root to: "pages#home"

  # Project wizard (creation flow)
  get  "projects/wizard/choose",   to: "projects/wizard#choose",     as: :wizard_choose
  post "projects/wizard/choose",   to: "projects/wizard#save_choose", as: :wizard_save_choose
  get  "projects/wizard/step1",    to: "projects/wizard#step1",      as: :wizard_step1
  post "projects/wizard/step1",    to: "projects/wizard#save_step1"
  get  "projects/wizard/step2",    to: "projects/wizard#step2",      as: :wizard_step2
  post "projects/wizard/step2",    to: "projects/wizard#save_step2"
  get  "projects/wizard/step3",    to: "projects/wizard#step3",      as: :wizard_step3
  post "projects/wizard/step3",    to: "projects/wizard#save_step3"
  get  "projects/wizard/step4",    to: "projects/wizard#step4",      as: :wizard_step4
  get  "projects/wizard/edit/:id", to: "projects/wizard#edit_recap", as: :wizard_edit
  post "projects/wizard/generate",    to: "projects/wizard#generate",    as: :wizard_generate
  post "projects/wizard/analyze_url",  to: "projects/wizard#analyze_url",  as: :wizard_analyze_url
  post "projects/wizard/chat_property", to: "projects/wizard#chat_property", as: :wizard_chat_property
  post "projects/wizard/analyze_pdf",   to: "projects/wizard#analyze_pdf",   as: :wizard_analyze_pdf

  resources :projects do
    resources :rooms,     only: [:index, :new, :create]
    resources :documents, only: [:index, :new, :create]
    resource :bidding_round, only: [:new, :create, :show] do
      post   :send_requests,      on: :member
      get    :select_artisans,    on: :member
      patch  :update_artisans,    on: :member
      get    :review_responses,    on: :member
      post   :confirm_selections,  on: :member
      get    :final_quote,         on: :member
      get    :select_replacement,  on: :member
      post   :replace_artisan,     on: :member
    end
  end

  get  "artisan/respond/:token", to: "artisan_portal#show",   as: :artisan_portal
  post "artisan/respond/:token", to: "artisan_portal#submit",  as: :artisan_portal_submit

  namespace :artisan_dashboard do
    root to: "home#index"
    resources :requests, only: [:index, :show] do
      post :submit_price, on: :member
      post :decline,      on: :member
    end
    resource :profile, only: [:show, :edit, :update]
  end

  post "webhooks/inbound_email", to: "webhooks/inbound_email#create"

  resources :notifications, only: [:index] do
    post :mark_read, on: :member
  end

  resources :rooms, only: [:show, :edit, :update, :destroy] do
    resources :work_items, only: [:new, :create]
  end

  resources :work_items, only: [:edit, :update, :destroy]
  resources :documents,  only: [:destroy]

  resource :profile, only: [:show, :edit, :update]

  resources :work_categories, only: [:index, :show]
  resources :materials,       only: [:index, :show]

  get "up" => "rails/health#show", as: :rails_health_check
end
