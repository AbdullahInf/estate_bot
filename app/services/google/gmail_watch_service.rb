module Google
  class GmailWatchService
    WATCH_URL = "https://gmail.googleapis.com/gmail/v1/users/me/watch"

    def initialize(broker)
      @broker       = broker
      @access_token = broker.fresh_access_token
    end

    def setup
      return if watch_active?

      response = Faraday.post(WATCH_URL) do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.headers["Content-Type"]  = "application/json"
        req.body = { topicName: ENV.fetch("GOOGLE_PUBSUB_TOPIC"), labelIds: [ "INBOX" ] }.to_json
      end

      data = JSON.parse(response.body)
      raise "Gmail watch setup failed: #{data.dig('error', 'message')}" if data["error"].present?

      @broker.update!(
        # Only seed historyId on first-ever setup so we don't skip messages already queued
        gmail_history_id:      @broker.gmail_history_id.presence || data["historyId"],
        gmail_watch_expiration: Time.at(data["expiration"].to_i / 1000)
      )
    end

    private

    def watch_active?
      @broker.gmail_watch_expiration.present? && @broker.gmail_watch_expiration > 1.day.from_now
    end
  end
end
