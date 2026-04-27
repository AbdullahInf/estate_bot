module Webhooks
  class WhatsappController < ActionController::Base
    skip_before_action :verify_authenticity_token
    before_action :verify_webhook_signature, only: :create

    # GET /webhooks/whatsapp — Meta webhook verification
    def verify
      mode      = params["hub.mode"]
      token     = params["hub.verify_token"]
      challenge = params["hub.challenge"]

      if mode == "subscribe" && token == ENV.fetch("WHATSAPP_VERIFY_TOKEN", "")
        render plain: challenge
      else
        head :forbidden
      end
    end

    # POST /webhooks/whatsapp — incoming messages
    def create
      payload = JSON.parse(request.body.read)
      messages = Whatsapp::MessageParser.extract_messages(payload)

      messages.each do |msg|
        ProcessInboundMessageJob.perform_later(msg)
      end

      head :ok
    end

    private

    def verify_webhook_signature
      secret    = ENV["WHATSAPP_APP_SECRET"]
      return if secret.blank?

      signature = request.headers["X-Hub-Signature-256"]&.delete_prefix("sha256=")
      expected  = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)

      head :forbidden unless ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected)
    end
  end
end
