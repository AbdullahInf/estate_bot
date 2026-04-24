class InboundEmail < ApplicationRecord
  belongs_to :broker
  has_many   :email_attachments, dependent: :destroy

  validates :gmail_message_id, presence: true, uniqueness: true

  scope :unprocessed, -> { where(processed: false) }
  scope :recent,      -> { order(received_at: :desc) }
end
