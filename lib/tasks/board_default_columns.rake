namespace :boards do
  desc "Add default columns to all existing boards that don't have any columns"
  task add_default_columns: :environment do
    puts "Adding default columns to boards without columns..."
    
    boards_updated = 0
    
    Board.find_each do |board|
      next if board.columns.any?
      
      puts "Adding default columns to board: #{board.name}"
      
      Board::DefaultColumns::DEFAULT_COLUMNS.each do |column_name|
        board.columns.create!(name: column_name, account: board.account)
      end
      
      boards_updated += 1
    end
    
    puts "✅ Added default columns to #{boards_updated} board(s)"
  end
end
