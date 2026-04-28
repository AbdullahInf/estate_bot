class DashboardController < ApplicationController
  before_action :require_broker
  layout false

  EXPECTED_DOCS = 8

  def index
    base  = current_broker.inbound_emails

    @clients = base
      .select(
        "sender_email",
        "MAX(sender_name) AS sender_name",
        "COUNT(DISTINCT inbound_emails.id) AS email_count",
        "COUNT(email_attachments.id) AS doc_count",
        "MAX(inbound_emails.received_at) AS last_email_at"
      )
      .left_joins(:email_attachments)
      .group("sender_email")
      .order("MAX(inbound_emails.received_at) DESC")

    @total_clients      = @clients.length
    @needs_attention    = @clients.count { |c| c.doc_count.to_i < EXPECTED_DOCS }
    @fully_ready        = @clients.select { |c| c.doc_count.to_i >= EXPECTED_DOCS }
    @docs_this_week     = base.joins(:email_attachments)
                              .where("inbound_emails.received_at >= ?", 1.week.ago)
                              .count
    @emails_last_7_days = base.where("received_at >= ?", 7.days.ago).count

    @recent_activity = base
      .select("inbound_emails.*, COUNT(email_attachments.id) AS attachment_count")
      .left_joins(:email_attachments)
      .group("inbound_emails.id")
      .order("received_at DESC")
      .limit(10)
  end
end
