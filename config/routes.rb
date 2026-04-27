require "sidekiq/web"

Rails.application.routes.draw do
  get  "up" => "rails/health#show", as: :rails_health_check

  # Google OAuth — OmniAuth posts to /auth/google_oauth2 (handled by middleware),
  # then redirects back to this callback route.
  get  "/auth/google_oauth2/callback", to: "auth/google_callbacks#create"
  get  "/auth/failure",                to: "auth#new"
  get  "/signin",                      to: "auth#new",     as: :signin
  delete "/signout",                   to: "auth#destroy",  as: :signout

  # WhatsApp Business API webhook
  scope :webhooks do
    get  "whatsapp", to: "webhooks/whatsapp#verify"
    post "whatsapp", to: "webhooks/whatsapp#create"
    post "gmail",    to: "webhooks/gmail#create"
  end

  # Attachment downloads
  get "attachments/:id/download", to: "attachments#download", as: :download_attachment

  # Browser chat simulator (dev/test only)
  get    "chat",         to: "chat#index",   as: :chat
  post   "chat/message", to: "chat#message", as: :chat_message
  post   "chat/voice",   to: "chat#voice",   as: :chat_voice
  delete "chat/reset",   to: "chat#reset",   as: :reset_chat

  # Sidekiq dashboard (restrict in production)
  mount Sidekiq::Web => "/sidekiq"

  get "/privacy", to: "pages#privacy", as: :privacy

  root to: "auth#new"
end
