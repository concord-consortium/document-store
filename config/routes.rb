Rails.application.routes.draw do
  resources :documents

  # CODAP API
  get 'document/all' => 'documents#all'
  get 'document/open' => 'documents#open'
  get 'document/launch' => 'documents#launch', :as => :launch
  get 'document/report' => 'documents#report', :as => :report
  post 'document/save' => 'documents#save'
  post 'document/patch' => 'documents#patch'
  get 'document/rename' => 'documents#rename'
  get 'document/delete' => 'documents#delete'
  get 'user/info' => 'users#info'
  get 'user/authenticate' => 'users#authenticate'

  get 'document/v2/open' => 'documents_v2#open'
  post 'document/v2/save' => 'documents_v2#save'
  post 'document/v2/patch' => 'documents_v2#patch'
  patch 'document/v2/patch' => 'documents_v2#patch'
  post 'document/v2/copy_shared' => 'documents_v2#copy_shared'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations", :omniauth_callbacks => "omniauth_callbacks"}
  resources :users
end
