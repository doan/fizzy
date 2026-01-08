class ImportedClickupTask < ApplicationRecord
  belongs_to :account
  belongs_to :card, optional: true

  validates :external_id, presence: true
  validates :account_id, presence: true

  scope :for_account, ->(account) { where(account: account) }
  scope :imported, -> { where.not(card_id: nil) }
  scope :pending, -> { where(card_id: nil) }
end
