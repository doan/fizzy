namespace :clickup do
  desc "Import all data from ClickUp CSV file"
  task :import_csv, [:csv_path] => :environment do |_t, args|
    csv_path = args[:csv_path] || ENV["CLICKUP_CSV_PATH"]

    unless csv_path && File.exist?(csv_path)
      puts "Error: CLICKUP_CSV_PATH must point to a valid CSV file"
      puts "Usage: rake clickup:import_csv[path/to/file.csv]"
      puts "   or: CLICKUP_CSV_PATH=path/to/file.csv rake clickup:import_csv"
      exit 1
    end

    puts "Starting ClickUp CSV import..."
    puts "CSV file: #{csv_path}"
    puts "Account: #{Import::Context.account.name}"

    importer = Import::ClickupCsvImporter.new(csv_path: csv_path)
    result = importer.import_all

    puts "Import completed!"
    puts "  Imported: #{result[:imported]}"
    puts "  Skipped: #{result[:skipped]}"
    puts "  Errors: #{result[:errors]}"
  end

  desc "Import all data from ClickUp API"
  task :import_api, [:api_token, :space_id] => :environment do |_t, args|
    api_token = args[:api_token] || ENV["CLICKUP_API_TOKEN"]
    space_id = args[:space_id] || ENV["CLICKUP_SPACE_ID"]

    unless api_token && space_id
      puts "Error: CLICKUP_API_TOKEN and CLICKUP_SPACE_ID are required"
      puts "Usage: rake clickup:import_api[api_token,space_id]"
      puts "   or: CLICKUP_API_TOKEN=xxx CLICKUP_SPACE_ID=xxx rake clickup:import_api"
      exit 1
    end

    puts "Starting ClickUp API import..."
    puts "Space ID: #{space_id}"
    puts "Account: #{Import::Context.account.name}"

    importer = Import::ClickupImporter.new(
      api_token: api_token,
      space_id: space_id
    )

    importer.import_all

    puts "Import completed!"
  end

  # Legacy task name for backward compatibility
  task :import, [:api_token, :space_id] => :import_api
end
