module ClickupImportCreatorFixer
  module_function
  
  def extract_creator_from_imported_task(imported_task, account, system_user)
    raw_payload = imported_task.raw_payload
    
    # Determine if this is from CSV or API import
    # CSV imports have raw_payload as a hash with keys like "Task ID", "Assignees"
    # API imports have raw_payload with keys like "id", "creator", "created_by"
    
    if raw_payload.is_a?(Hash)
      # Check if it's an API import (has "id" key and creator/created_by)
      if raw_payload.key?("id") && (raw_payload.key?("creator") || raw_payload.key?("created_by"))
        extract_creator_from_api_payload(raw_payload, account, system_user)
      # Otherwise assume it's a CSV import (has "Task ID" or assignees)
      elsif raw_payload.key?("Task ID") || raw_payload.key?(" Task ID") || raw_payload.key?("Assignees") || raw_payload.key?(" Assignees")
        extract_creator_from_csv_payload(raw_payload, account, system_user)
      # Try assignees field as fallback
      elsif imported_task.assignees.present?
        extract_creator_from_assignees(imported_task.assignees, account, system_user)
      else
        system_user
      end
    elsif imported_task.assignees.present?
      # If raw_payload is not useful, try assignees field
      extract_creator_from_assignees(imported_task.assignees, account, system_user)
    else
      system_user
    end
  end
  
  def extract_creator_from_api_payload(task_data, account, system_user)
    creator_data = task_data["creator"] || task_data["created_by"]
    return system_user unless creator_data
    
    # Try to find user by email (most reliable)
    email = creator_data["email"] || creator_data.dig("user", "email")
    if email.present?
      identity = Identity.find_by(email_address: email)
      if identity
        user = account.users.find_by(identity: identity)
        return user if user
      end
    end
    
    # Try to find by username
    username = creator_data["username"] || creator_data.dig("user", "username")
    if username.present?
      user = account.users.find_by("LOWER(name) LIKE ?", "%#{username.downcase}%")
      return user if user
    end
    
    system_user
  end
  
  def extract_creator_from_csv_payload(row, account, system_user)
    # CSV exports don't have creator info directly
    # Best guess: use the first assignee as the creator
    assignees_json = row["Assignees"] || row[" Assignees"]
    if assignees_json.present? && assignees_json != "[]" && assignees_json != "null"
      begin
        assignee_list = JSON.parse(assignees_json)
        if assignee_list.is_a?(Array) && assignee_list.any?
          creator = find_user_by_name_or_email(assignee_list.first, account)
          return creator if creator
        end
      rescue JSON::ParserError
        # Not JSON, try as single string
        creator = find_user_by_name_or_email(assignees_json, account)
        return creator if creator
      end
    end
    
    system_user
  end
  
  def extract_creator_from_assignees(assignees_text, account, system_user)
    return system_user if assignees_text.blank?
    
    # Try to parse as comma-separated list
    assignee_list = assignees_text.split(",").map(&:strip)
    if assignee_list.any?
      creator = find_user_by_name_or_email(assignee_list.first, account)
      return creator if creator
    end
    
    system_user
  end
  
  def find_user_by_name_or_email(identifier, account)
    return nil if identifier.blank?
    
    # Try to find by email first
    identity = Identity.find_by(email_address: identifier)
    if identity
      return account.users.find_by(identity: identity)
    end
    
    # Try to find by name (partial match)
    account.users.find_by("LOWER(name) LIKE ?", "%#{identifier.downcase}%")
  end
end

namespace :clickup do
  desc "Fix creator for existing imported cards that show 'By System'"
  task fix_imported_card_creators: :environment do
    account = Import::Context.account
    system_user = account.system_user
    
    puts "Finding imported cards created by system user..."
    imported_tasks = ImportedClickupTask
      .where(account: account)
      .where.not(card_id: nil)
      .includes(:card)
      .where(cards: { creator_id: system_user.id })
    
    total = imported_tasks.count
    puts "Found #{total} imported cards created by system user"
    puts ""
    
    updated_count = 0
    skipped_count = 0
    
    imported_tasks.find_each do |imported_task|
      card = imported_task.card
      next unless card
      
      creator = ClickupImportCreatorFixer.extract_creator_from_imported_task(imported_task, account, system_user)
      
      if creator && creator != system_user
        old_current_user = Current.user
        Current.user = creator
        
        begin
          # Update the card's creator
          card.update_column(:creator_id, creator.id)
          
          # Update the "added" event's creator if it exists
          added_event = card.board.events.find_by(
            action: "card_added",
            eventable: card
          )
          if added_event
            added_event.update_column(:creator_id, creator.id)
          end
          
          updated_count += 1
          puts "  ✓ Updated card ##{card.number} '#{card.title[0..50]}...' to creator: #{creator.name}"
        ensure
          Current.user = old_current_user
        end
      else
        skipped_count += 1
        puts "  - Skipped card ##{card.number} '#{card.title[0..50]}...' (no creator found)"
      end
    end
    
    puts ""
    puts "✅ Fix completed!"
    puts "  Updated: #{updated_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Total: #{total}"
  end
end
