module Google
  class GmailService
    BASE_URL = "https://gmail.googleapis.com/gmail/v1/users/me"

    def initialize(access_token)
      @access_token = access_token
    end

    def search_emails(query:, max_results: 15)
      resp = get("messages", q: query, maxResults: max_results)
      messages = resp["messages"] || []
      return [] if messages.empty?

      messages.map do |msg|
        meta = get_metadata(msg["id"])
        {
          id:      msg["id"],
          subject: header(meta, "Subject") || "(no subject)",
          from:    header(meta, "From"),
          date:    header(meta, "Date"),
          snippet: meta["snippet"]
        }
      end
    end

    def get_email(message_id:)
      msg = get("messages/#{message_id}", format: "full")
      {
        id:      msg["id"],
        subject: header(msg, "Subject") || "(no subject)",
        from:    header(msg, "From"),
        to:      header(msg, "To"),
        date:    header(msg, "Date"),
        body:    extract_body(msg)
      }
    end

    private

    def get_metadata(message_id)
      response = Faraday.get("#{BASE_URL}/messages/#{message_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.params["format"] = "full"
      end
      JSON.parse(response.body)
    end

    def get(path, params = {})
      response = Faraday.get("#{BASE_URL}/#{path}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.params.merge!(params)
      end
      JSON.parse(response.body)
    end

    def header(message, name)
      headers = message.dig("payload", "headers") || []
      headers.find { |h| h["name"].casecmp(name).zero? }&.dig("value")
    end

    def extract_body(message)
      payload = message["payload"] || {}

      data = payload.dig("body", "data")
      return decode(data) if data.present?

      parts = collect_parts(payload["parts"] || [])
      plain = parts.find { |p| p["mimeType"] == "text/plain" }
      html  = parts.find { |p| p["mimeType"] == "text/html" }
      part  = plain || html

      part&.dig("body", "data") ? decode(part.dig("body", "data")) : message["snippet"].to_s
    end

    def collect_parts(parts)
      parts.flat_map { |p| [ p ] + collect_parts(p["parts"] || []) }
    end

    def decode(data)
      Base64.urlsafe_decode64(data)
            .force_encoding("UTF-8")
            .encode("UTF-8", invalid: :replace, undef: :replace)
    end
  end
end
