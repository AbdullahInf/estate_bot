class AddGmailWatchExpirationToBrokers < ActiveRecord::Migration[7.2]
  def change
    add_column :brokers, :gmail_watch_expiration, :datetime
  end
end
