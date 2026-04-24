class AddFileDataToEmailAttachments < ActiveRecord::Migration[7.2]
  def change
    add_column :email_attachments, :file_data, :binary
  end
end
