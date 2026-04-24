class Message < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[user assistant].freeze
  TYPES = %w[text audio document image].freeze

  validates :role, inclusion: { in: ROLES }
  validates :message_type, inclusion: { in: TYPES }

  scope :ordered, -> { order(:created_at) }
end
