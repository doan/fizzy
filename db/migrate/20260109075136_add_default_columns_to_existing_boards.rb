class AddDefaultColumnsToExistingBoards < ActiveRecord::Migration[8.2]
  def up
    # Load the default columns constant
    default_columns = Board::DefaultColumns::DEFAULT_COLUMNS

    Board.find_each do |board|
      existing_column_names = board.columns.pluck(:name)
      missing_columns = default_columns - existing_column_names

      next if missing_columns.empty?

      default_color_value = Column::Colored::DEFAULT_COLOR.value
      
      columns_to_insert = missing_columns.map do |column_name|
        {
          id: SecureRandom.uuid,
          name: column_name,
          board_id: board.id,
          account_id: board.account_id,
          color: default_color_value,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      Column.insert_all(columns_to_insert) unless columns_to_insert.empty?
    end
  end

  def down
    # This migration is not reversible as we can't know which columns
    # were added by this migration vs. manually created by users
    raise ActiveRecord::IrreversibleMigration
  end
end
