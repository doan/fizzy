module Board::DefaultColumns
  extend ActiveSupport::Concern

  DEFAULT_COLUMNS = [
    "Todo",
    "In Progress",
    "Verifying"
  ].freeze

  included do
    after_create :create_default_columns, if: -> { columns.empty? }
  end

  private
    def create_default_columns
      DEFAULT_COLUMNS.each do |column_name|
        columns.create!(name: column_name, account: account)
      end
    end
end
