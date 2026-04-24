class AddGmailSyncFieldsToBrokers < ActiveRecord::Migration[7.2]
  def change
    add_column :brokers, :gmail_history_id,   :string
    add_column :brokers, :gmail_sync_started_at, :datetime
  end
end
