class TimeEntry < ApplicationRecord
  belongs_to :card
  belongs_to :user
  belongs_to :account

  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :account_id, presence: true

  scope :for_card, ->(card) { where(card: card) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }
end
