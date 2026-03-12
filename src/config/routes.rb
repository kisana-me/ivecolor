Rails.application.routes.draw do
  root "pages#index"

  # Pages
  get "terms-of-service" => "pages#terms_of_service"
  get "privacy-policy" => "pages#privacy_policy"
  get "contact" => "pages#contact"
  # get "sitemap" => "pages#sitemap"

  # Sitemaps
  get "sitemap", to: "sitemaps#index", defaults: { format: "xml" }

  # Sessions
  get "sessions/start"
  delete "signout" => "sessions#signout"
  resources :sessions, except: %i[new create], param: :aid

  # Signup
  get "signup" => "signup#new"
  post "signup" => "signup#create"

  # OAuth
  post "oauth/start" => "oauth#start"
  get "oauth/callback" => "oauth#callback"
  post "oauth/fetch" => "oauth#fetch"

  # Accounts
  resources :accounts, param: :name_id, only: %i[index show]

  # Posts
  resources :posts, param: :name_id

  # Images
  resources :images, param: :aid do
    member do
      post "variants_create" => "images#variants_create", as: "variants_create"
      delete "variants_destroy" => "images#variants_destroy", as: "variants_destroy"
    end
  end

  # Comments
  resources :comments, param: :aid, only: %i[create update]

  # Tags
  resources :tags, param: :name_id

  # Studio
  get "studio" => "studio#index"

  # Settings
  get "settings" => "settings#index"
  get "settings/account" => "settings#account"
  get "settings/icon" => "settings#icon"
  patch "settings/account" => "settings#post_account"
  delete "settings/leave" => "settings#leave"

  # Administorator
  namespace :admin do
    root "studio#index"
    get "studio/console" => "studio#console"
    post "studio/console" => "studio#post_console"
    resources :accounts, param: :aid, only: %i[index edit update]
    patch "posts/update_multiple", to: "posts#update_multiple", as: :update_multiple_posts
    resources :posts, param: :aid, only: %i[index edit update]
    resources :tags, param: :aid, only: [:index]
    resources :comments, param: :aid, only: [:index]
  end

  # API
  namespace :v1 do
    post "images/create" => "images#create"
  end

  # Others
  get "up" => "rails/health#show", as: :rails_health_check

  # Errors
  match "*path", to: "application#routing_error", via: :all
end
