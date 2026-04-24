class EmailAttachment < ApplicationRecord
  belongs_to :inbound_email

  validates :gmail_attachment_id, presence: true
end
