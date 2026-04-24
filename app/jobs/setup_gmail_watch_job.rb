class SetupGmailWatchJob < ApplicationJob
  queue_as :default

  def perform(broker_id)
    broker = Broker.find_by(id: broker_id)
    return unless broker&.google_refresh_token.present?

    Google::GmailWatchService.new(broker).setup
  rescue => e
    Rails.logger.error "[SetupGmailWatchJob] broker=#{broker_id} error=#{e.message}"
  end
end
