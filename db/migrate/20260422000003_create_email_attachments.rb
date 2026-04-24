class CreateEmailAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :email_attachments do |t|
      t.references :inbound_email,       null: false, foreign_key: true
      t.string     :filename
      t.string     :content_type
      t.integer    :size
      t.string     :gmail_attachment_id
      t.timestamps
    end
  end
end
