class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.string :phone_number, null: false
      t.string :contact_name
      t.jsonb :context, null: false, default: {}
      t.datetime :last_active_at

      t.timestamps
    end

    add_index :conversations, :phone_number, unique: true
  end
end
