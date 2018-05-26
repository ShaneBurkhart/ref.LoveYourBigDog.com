Prelaunchr::Application.routes.draw do

  root :to => "users#new"

  get 'r' => 'users#refer_redirect'
  post 'users/create' => 'users#create'
  get 'refer-a-friend' => 'users#refer'
  get 'privacy-policy' => 'users#policy'
  post 'webhook/opt-in-monster/6217d74f-b199-41cc-b34a-7b1c86f22a00' => 'users#optin_monster_webhook'

  unless Rails.application.config.consider_all_requests_local
    get '*not_found', to: 'users#redirect', :format => false
  end
end
