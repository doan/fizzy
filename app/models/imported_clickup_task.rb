class ImportedClickupTask < ApplicationRecord
  belongs_to :account

  validates :external_id, presence: true
  validates :account_id, presence: true

  scope :for_account, ->(account) { where(account: account) }
end
