namespace :clickup do
  desc "Import all data from ClickUp"
  task :import, [:api_token, :space_id] => :environment do |_t, args|
    api_token = args[:api_token] || ENV["CLICKUP_API_TOKEN"]
    space_id = args[:space_id] || ENV["CLICKUP_SPACE_ID"]

    unless api_token && space_id
      puts "Error: CLICKUP_API_TOKEN and CLICKUP_SPACE_ID are required"
      puts "Usage: rake clickup:import[api_token,space_id]"
      puts "   or: CLICKUP_API_TOKEN=xxx CLICKUP_SPACE_ID=xxx rake clickup:import"
      exit 1
    end

    puts "Starting ClickUp import..."
    puts "Space ID: #{space_id}"
    puts "Account: #{Import::Context.account.name}"

    importer = Import::ClickupImporter.new(
      api_token: api_token,
      space_id: space_id
    )

    importer.import_all

    puts "Import completed!"
  end

  desc "Import a specific folder from ClickUp"
  task :import_folder, [:api_token, :folder_id] => :environment do |_t, args|
    api_token = args[:api_token] || ENV["CLICKUP_API_TOKEN"]
    folder_id = args[:folder_id]

    unless api_token && folder_id
      puts "Error: CLICKUP_API_TOKEN and folder_id are required"
      puts "Usage: rake clickup:import_folder[api_token,folder_id]"
      exit 1
    end

    # For single folder import, we need to fetch folder details first
    # This is a simplified version - you might want to enhance it
    puts "Single folder import not yet implemented"
    puts "Use clickup:import to import all folders"
  end
end
