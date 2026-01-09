class AddDefaultColumnsToExistingBoards < ActiveRecord::Migration[8.2]
  def up
    # Load the default columns constant
    default_columns = Board::DefaultColumns::DEFAULT_COLUMNS

    Board.find_each do |board|
      existing_column_names = board.columns.pluck(:name)
      missing_columns = default_columns - existing_column_names

      next if missing_columns.empty?

      missing_columns.each do |column_name|
        board.columns.create!(
          name: column_name,
          account: board.account
        )
      end
    end
  end

  def down
    # This migration is not reversible as we can't know which columns
    # were added by this migration vs. manually created by users
    raise ActiveRecord::IrreversibleMigration
  end
end
