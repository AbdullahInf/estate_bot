module Google
  class GmailInboundService
    GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"

    def initialize(broker)
      @broker       = broker
      @access_token = broker.fresh_access_token
    end

    def sync
      if @broker.gmail_history_id.present?
        incremental_sync
      else
        initial_sync
      end
    end

    private

    def initial_sync
      resp        = get("messages", labelIds: "INBOX", maxResults: 100, q: "newer_than:30d")
      message_ids = (resp["messages"] || []).map { |m| m["id"] }
      message_ids.each { |id| ingest_message(id) }

      profile = get("profile")
      @broker.update!(
        gmail_history_id:      profile["historyId"],
        gmail_sync_started_at: Time.current
      )
    end

    def incremental_sync
      history_resp = get("history",
        startHistoryId: @broker.gmail_history_id,
        historyTypes:   "messageAdded",
        labelId:        "INBOX"
      )

      new_ids = (history_resp["history"] || []).flat_map do |entry|
        (entry["messagesAdded"] || []).map { |m| m["message"]["id"] }
      end.uniq

      new_ids.each { |id| ingest_message(id) }

      @broker.update!(gmail_history_id: history_resp["historyId"]) if history_resp["historyId"].present?
    rescue GmailApiError => e
      # historyId expired after ~7 days without polling — fall back to full re-sync
      raise unless e.status == 410
      @broker.update!(gmail_history_id: nil)
      initial_sync
    end

    def ingest_message(message_id)
      return if InboundEmail.exists?(gmail_message_id: message_id)

      msg = get("messages/#{message_id}", format: "full")
      return unless msg["id"].present?

      headers     = parse_headers(msg)
      sender_raw  = headers["From"].to_s

      inbound = @broker.inbound_emails.create!(
        gmail_message_id: msg["id"],
        gmail_thread_id:  msg["threadId"],
        sender_email:     extract_email(sender_raw),
        sender_name:      extract_name(sender_raw),
        subject:          headers["Subject"].presence || "(no subject)",
        body_text:        extract_body(msg, "text/plain"),
        body_html:        extract_body(msg, "text/html"),
        received_at:      Time.at(msg["internalDate"].to_i / 1000)
      )

      extract_attachments(msg).each do |att|
        file_data = fetch_attachment_data(msg["id"], att[:gmail_attachment_id])
        inbound.email_attachments.create!(att.merge(file_data: file_data))
      end

      inbound
    rescue => e
      Rails.logger.error "[GmailInboundService] Failed to ingest message #{message_id}: #{e.message}"
    end

    def parse_headers(msg)
      (msg.dig("payload", "headers") || []).each_with_object({}) { |h, acc| acc[h["name"]] = h["value"] }
    end

    def extract_email(from)
      match = from.match(/<(.+?)>/)
      match ? match[1].strip : from.strip
    end

    def extract_name(from)
      match = from.match(/^"?([^"<]+)"?\s*</)
      match ? match[1].strip : nil
    end

    def extract_body(msg, mime_type)
      payload = msg["payload"] || {}

      if payload["mimeType"] == mime_type
        data = payload.dig("body", "data")
        return decode(data) if data.present?
      end

      parts = collect_parts(payload["parts"] || [])
      part  = parts.find { |p| p["mimeType"] == mime_type }
      data  = part&.dig("body", "data")
      data.present? ? decode(data) : nil
    end

    def collect_parts(parts)
      parts.flat_map { |p| [ p ] + collect_parts(p["parts"] || []) }
    end

    def extract_attachments(msg)
      collect_parts(msg.dig("payload", "parts") || [])
        .select { |p| p["filename"].present? && p.dig("body", "attachmentId").present? }
        .map do |p|
          {
            filename:            p["filename"],
            content_type:        p["mimeType"],
            size:                p.dig("body", "size"),
            gmail_attachment_id: p.dig("body", "attachmentId")
          }
        end
    end

    def fetch_attachment_data(message_id, attachment_id)
      response = Faraday.get("#{GMAIL_API}/messages/#{message_id}/attachments/#{attachment_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
      end
      result = JSON.parse(response.body)
      Base64.urlsafe_decode64(result["data"]) if result["data"].present?
    rescue => e
      Rails.logger.error "[GmailInboundService] Failed to download attachment #{attachment_id}: #{e.message}"
      nil
    end

    def decode(data)
      Base64.urlsafe_decode64(data)
            .force_encoding("UTF-8")
            .encode("UTF-8", invalid: :replace, undef: :replace)
    end

    def get(path, params = {})
      response = Faraday.get("#{GMAIL_API}/#{path}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
        req.params.merge!(params.transform_keys(&:to_s))
      end
      result = JSON.parse(response.body)
      raise GmailApiError.new(result.dig("error", "message").to_s, response.status) if response.status >= 400
      result
    end

    class GmailApiError < StandardError
      attr_reader :status
      def initialize(msg, status)
        super(msg)
        @status = status
      end
    end
  end
end
