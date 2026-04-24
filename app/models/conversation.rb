class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  validates :phone_number, presence: true, uniqueness: true

  def self.find_or_create_for(phone_number, contact_name: nil)
    conversation = find_or_create_by!(phone_number: phone_number)
    conversation.update!(contact_name: contact_name, last_active_at: Time.current) if contact_name
    conversation.touch(:last_active_at)
    conversation
  end

  def recent_messages(limit = 20)
    messages.order(:created_at).last(limit)
  end
end
