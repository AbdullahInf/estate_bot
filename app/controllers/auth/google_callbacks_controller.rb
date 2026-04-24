class Auth::GoogleCallbacksController < ApplicationController
  def create
    broker = Broker.from_omniauth(request.env["omniauth.auth"])
    session[:broker_id] = broker.id
    SetupGmailWatchJob.perform_later(broker.id)
    SyncGmailInboxJob.perform_later(broker.id)
    redirect_to chat_path, notice: "Welcome, #{broker.name}!"
  rescue => e
    Rails.logger.error "Google OAuth error: #{e.message}"
    redirect_to signin_path, alert: "Sign in failed. Please try again."
  end
end
