namespace :clickup do
  desc "Fix untitled cards with correct titles from CSV"
  task :fix_titles, [:csv_path] => :environment do |_t, args|
    csv_path = args[:csv_path] || ENV["CLICKUP_CSV_PATH"]

    unless csv_path
      puts "Error: CSV_PATH is required"
      puts "Usage: rake clickup:fix_titles[path/to/file.csv]"
      exit 1
    end

    require "csv"
    require "json"

    updated = 0
    skipped = 0

    CSV.foreach(csv_path, headers: true, encoding: "UTF-8", liberal_parsing: true) do |row|
      task_id = row["Task ID"] || row[" Task ID"]
      next if task_id.blank?

      imported_task = ImportedClickupTask.find_by(external_id: task_id)
      next unless imported_task&.card

      task_name = row["Task Name"] || row[" Task Name"]
      next if task_name.blank? || task_name == "Untitled"

      card = imported_task.card
      next unless card.title == "Untitled" || card.title.blank?

      # Add bug/feature prefix if in tags
      tags_json = row["Tags"] || row[" Tags"]
      prefix = nil
      if tags_json.present? && tags_json != "[]" && tags_json != "null"
        begin
          tags = JSON.parse(tags_json)
          prefix = "bug" if tags.any? { |t| t.downcase == "bug" }
          prefix = "feature" if tags.any? { |t| t.downcase == "feature" }
        rescue JSON::ParserError
          # Ignore parse errors
        end
      end

      new_title = prefix ? "[#{prefix}] #{task_name}" : task_name
      card.update!(title: new_title)
      updated += 1
    end

    puts "✅ Updated #{updated} card titles"
    puts "   Skipped #{skipped} cards (already have titles)"
  end
end
