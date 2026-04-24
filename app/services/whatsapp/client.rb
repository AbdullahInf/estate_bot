module Whatsapp
  class Client
    BASE_URL = "https://graph.facebook.com/v19.0"

    def initialize
      @token            = ENV.fetch("WHATSAPP_ACCESS_TOKEN", "")
      @phone_number_id  = ENV.fetch("WHATSAPP_PHONE_NUMBER_ID", "")
      @conn             = Faraday.new(url: BASE_URL) do |f|
        f.request  :json
        f.response :json
        f.adapter  Faraday.default_adapter
      end
    end

    def send_text(to:, body:)
      post("#{@phone_number_id}/messages", {
        messaging_product: "whatsapp",
        to: to,
        type: "text",
        text: { body: body }
      })
    end

    def download_media(media_id)
      # Step 1: get the media URL
      url_response = @conn.get("#{media_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
      end
      media_url = url_response.body["url"]
      return nil unless media_url

      # Step 2: download the binary
      raw = Faraday.new.get(media_url) do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
      end

      raw.body
    end

    private

    def post(path, body)
      @conn.post(path) do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.body = body
      end
    end
  end
end
