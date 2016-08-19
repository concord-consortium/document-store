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

  get 'v2/document/:id' => 'documents_v2#open'
  put 'v2/document/:id' => 'documents_v2#save'
  patch 'v2/document/:id' => 'documents_v2#patch'
  post 'v2/document' => 'documents_v2#copy_shared'

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations", :omniauth_callbacks => "omniauth_callbacks"}
  resources :users
end
