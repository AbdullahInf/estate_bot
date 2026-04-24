class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.string :message_type, null: false, default: "text"
      t.string :whatsapp_message_id
      t.string :media_id
      t.jsonb :raw_payload, default: {}

      t.timestamps
    end

    add_index :messages, :whatsapp_message_id, unique: true, where: "whatsapp_message_id IS NOT NULL"
    add_index :messages, [ :conversation_id, :created_at ]
  end
end
