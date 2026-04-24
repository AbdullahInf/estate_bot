class CreateBrokers < ActiveRecord::Migration[7.2]
  def change
    create_table :brokers do |t|
      t.string   :email,                   null: false
      t.string   :name
      t.string   :google_uid,              null: false
      t.string   :google_access_token
      t.string   :google_refresh_token
      t.datetime :google_token_expires_at

      t.timestamps
    end

    add_index :brokers, :email,      unique: true
    add_index :brokers, :google_uid, unique: true
  end
end
