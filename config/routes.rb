Rails.application.routes.draw do
  resources :documents

  # CODAP API
  get 'document/all' => 'documents#all'
  get 'document/open' => 'documents#open'
  get 'document/launch' => 'documents#launch', :as => :launch
  post 'document/save' => 'documents#save'
  get 'document/rename' => 'documents#rename'
  get 'document/delete' => 'documents#delete'
  get 'user/info' => 'users#info'
  get 'user/authenticate' => 'users#authenticate'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations", :omniauth_callbacks => "omniauth_callbacks"}
  resources :users
end
