module Google
  class GmailAttachmentService
    GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"

    def initialize(broker)
      @access_token = broker.fresh_access_token
    end

    # Returns raw binary content of the attachment.
    def download(email_attachment)
      message_id    = email_attachment.inbound_email.gmail_message_id
      attachment_id = email_attachment.gmail_attachment_id

      response = Faraday.get("#{GMAIL_API}/messages/#{message_id}/attachments/#{attachment_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@access_token}"
      end

      data = JSON.parse(response.body)
      raise "Gmail attachment fetch failed: #{data.dig('error', 'message')}" if data["error"].present?

      Base64.urlsafe_decode64(data["data"])
    end
  end
end
