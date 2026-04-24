class SyncGmailInboxJob < ApplicationJob
  queue_as :default

  def perform(broker_id)
    broker = Broker.find_by(id: broker_id)
    return unless broker&.google_refresh_token.present?

    Google::GmailInboundService.new(broker).sync
  end
end
