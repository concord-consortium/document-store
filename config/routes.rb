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

  get 'v2/documents/:id' => 'documents_v2#open', :as => :v2_document_open
  put 'v2/documents/:id' => 'documents_v2#save', :as => :v2_document_save
  patch 'v2/documents/:id' => 'documents_v2#patch', :as => :v2_document_patch
  post 'v2/documents' => 'documents_v2#create', :as => :v2_document_create
  get 'v2/documents/:id/launch' => 'documents_v2#launch', :as => :v2_document_launch
  post 'v2/documents/create_keys' => 'documents_v2#create_keys', :as => :v2_document_create_keys

  root :to => "home#index"
  devise_for :users, :controllers => {:registrations => "registrations", :omniauth_callbacks => "omniauth_callbacks"}
  resources :users
end
