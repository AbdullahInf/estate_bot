class AttachmentsController < ApplicationController
  before_action :require_broker

  def download
    attachment = EmailAttachment
                   .joins(:inbound_email)
                   .where(inbound_emails: { broker_id: current_broker.id })
                   .find(params[:id])

    data = attachment.file_data.presence ||
           Google::GmailAttachmentService.new(current_broker).download(attachment)

    send_data data,
              filename:    attachment.filename,
              type:        attachment.content_type.presence || "application/octet-stream",
              disposition: "attachment"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue => e
    Rails.logger.error "[AttachmentsController] download failed: #{e.message}"
    head :internal_server_error
  end
end
