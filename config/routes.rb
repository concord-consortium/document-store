Rails.application.routes.draw do
  resources :documents

  # CODAP API
  get 'document/all' => 'documents#all'
  get 'document/open' => 'documents#open'
  post 'document/save' => 'documents#save'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations", :omniauth_callbacks => "omniauth_callbacks"}
  resources :users
end
