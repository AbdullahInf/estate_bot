class Webhooks::GmailController < ActionController::Base
  skip_before_action :verify_authenticity_token

  # Receives Gmail push notifications forwarded via Google Cloud Pub/Sub.
  # Setup: create a Pub/Sub topic, grant gmail-api-push@system.gserviceaccount.com
  # the "Pub/Sub Publisher" role, then call gmail.users.watch() after broker login.
  def create
    encoded = params.dig(:message, :data)
    return head :bad_request unless encoded.present?

    data   = JSON.parse(Base64.decode64(encoded))
    broker = Broker.find_by(email: data["emailAddress"])
    SyncGmailInboxJob.perform_later(broker.id) if broker

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
