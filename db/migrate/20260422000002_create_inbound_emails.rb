class CreateInboundEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :inbound_emails do |t|
      t.references :broker,          null: false, foreign_key: true
      t.string     :gmail_message_id, null: false
      t.string     :gmail_thread_id
      t.string     :sender_email
      t.string     :sender_name
      t.string     :subject
      t.text       :body_text
      t.text       :body_html
      t.datetime   :received_at
      t.boolean    :processed,        null: false, default: false
      t.timestamps
    end

    add_index :inbound_emails, :gmail_message_id, unique: true
    add_index :inbound_emails, [ :broker_id, :received_at ]
  end
end
