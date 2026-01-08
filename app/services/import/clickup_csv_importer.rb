# app/services/import/clickup_csv_importer.rb

require "csv"
require "json"

module Import
  class ClickupCsvImporter
    # Status mapping: ClickUp Status → Fizzy Status
    STATUS_MAP = {
      "to do" => "open",
      "backlog" => "open",
      "in progress" => "in_progress",
      "review" => "in_review",
      "blocked" => "blocked",
      "done" => "done",
      "complete" => "done"
    }.freeze

    attr_reader :account, :system_user, :csv_path

    def initialize(csv_path:, account: nil)
      @csv_path = csv_path
      @account = account || Import::Context.account
      @system_user = @account.system_user
      @folder_boards = {} # Cache folder → board mapping
      @status_columns = {} # Cache status → column mapping per board
    end

    def import_all
      Rails.logger.info "Starting ClickUp CSV import for account: #{account.name}"
      Rails.logger.info "Reading CSV from: #{csv_path}"

      imported_count = 0
      skipped_count = 0
      error_count = 0

      CSV.foreach(csv_path, headers: true, encoding: "UTF-8", liberal_parsing: true) do |row|
        begin
          if import_task(row)
            imported_count += 1
          else
            skipped_count += 1
          end
        rescue => e
          Rails.logger.error "Error importing task #{row['Task ID']}: #{e.message}"
          error_count += 1
        end
      end

      Rails.logger.info "ClickUp CSV import completed"
      Rails.logger.info "  Imported: #{imported_count}"
      Rails.logger.info "  Skipped: #{skipped_count}"
      Rails.logger.info "  Errors: #{error_count}"

      { imported: imported_count, skipped: skipped_count, errors: error_count }
    end

    private

      def import_task(row)
        task_id = row["Task ID"]
        return false if task_id.blank?

        # Check if already imported
        existing = ImportedClickupTask.find_by(external_id: task_id, account: account)
        if existing&.card
          Rails.logger.debug "Task #{task_id} already imported, skipping"
          return false
        end

        # Get folder name (first folder if array)
        folder_name = extract_folder_name(row)
        return false if folder_name.blank?

        # Get or create board for this folder
        board = find_or_create_board(folder_name)

        # Get list name for label
        list_name = row["List Name"]&.strip
        list_name = nil if list_name.blank?

        # Create or update imported task record
        imported_task = ImportedClickupTask.find_or_initialize_by(
          external_id: task_id,
          account: account
        )

        imported_task.assign_attributes(
          folder_name: folder_name,
          list_name: list_name,
          title: row["Task Name"] || "Untitled",
          description: extract_description(row),
          status: row["Status"]&.downcase || "unknown",
          priority: extract_priority(row),
          assignees: extract_assignees_text(row),
          raw_payload: row.to_h
        )

        imported_task.save!

        # Create Fizzy card from ClickUp task
        card = create_card_from_task(board, row, imported_task, list_name)

        # Link the imported task to the created card
        imported_task.update!(card: card)

        true
      end

      def extract_folder_name(row)
        folder_path = row["Folder Name/Path"]
        return nil if folder_path.blank?

        # Folder path might be JSON array like ["App Wars"] or just a string
        begin
          folders = JSON.parse(folder_path)
          folders.is_a?(Array) ? folders.first : folders.to_s
        rescue JSON::ParserError
          # Not JSON, treat as string
          folder_path.strip
        end
      end

      def extract_description(row)
        content = row["Task Content"]
        return "" if content.blank? || content == "null"

        # ClickUp content might be markdown or HTML
        content
      end

      def extract_priority(row)
        priority = row["Priority"]
        return "normal" if priority.blank? || priority == "null"

        # ClickUp priority: 1=urgent, 2=high, 3=normal, 4=low
        case priority.to_i
        when 1 then "urgent"
        when 2 then "high"
        when 3 then "normal"
        when 4 then "low"
        else "normal"
        end
      end

      def extract_assignees_text(row)
        assignees = row["Assignees"]
        return "" if assignees.blank? || assignees == "[]" || assignees == "null"

        begin
          assignee_list = JSON.parse(assignees)
          assignee_list.is_a?(Array) ? assignee_list.join(", ") : assignees
        rescue JSON::ParserError
          assignees
        end
      end

      def find_or_create_board(folder_name)
        return @folder_boards[folder_name] if @folder_boards[folder_name]

        board = account.boards.find_by(name: folder_name)
        unless board
          board = account.boards.create!(
            name: folder_name,
            creator: system_user,
            account: account
          )
        end

        @folder_boards[folder_name] = board
        board
      end

      def find_or_create_column_for_status(board, status)
        # Cache columns per board
        cache_key = "#{board.id}:#{status}"
        return @status_columns[cache_key] if @status_columns[cache_key]

        # Map ClickUp status to Fizzy status
        fizzy_status = STATUS_MAP[status&.downcase] || "open"

        # Find or create column for this status
        column_name = case fizzy_status
        when "in_progress" then "In Progress"
        when "in_review" then "In Review"
        when "blocked" then "Blocked"
        when "done" then "Done"
        else
          nil # Open tasks don't need a column (awaiting triage)
        end

        column = nil
        if column_name
          column = board.columns.find_by(name: column_name)
          unless column
            column = board.columns.create!(
              name: column_name,
              account: account,
              board: board
            )
          end
        end

        @status_columns[cache_key] = column
        column
      end

      def create_card_from_task(board, row, imported_task, list_name)
        task_name = row["Task Name"] || "Untitled"
        status = row["Status"]&.downcase || "backlog"

        # Add bug/feature prefix if in tags
        tags_json = row["Tags"]
        prefix = extract_bug_feature_prefix(tags_json)
        title = prefix ? "[#{prefix}] #{task_name}" : task_name

        # Create card
        card = board.cards.build(
          account: account,
          board: board,
          creator: system_user,
          title: title,
          status: "published"
        )

        # Set description if present
        if imported_task.description.present?
          card.description = imported_task.description
        end

        # Set created_at from ClickUp date
        if row["Date Created"].present?
          begin
            created_timestamp = row["Date Created"].to_i / 1000 # Convert ms to seconds
            card.created_at = Time.at(created_timestamp)
          rescue => e
            Rails.logger.warn "Could not parse created date: #{e.message}"
          end
        end

        # Set due date if present
        if row["Due Date"].present? && row["Due Date"] != "null"
          begin
            due_timestamp = row["Due Date"].to_i / 1000
            due_date = Time.at(due_timestamp)
            card.due_on = due_date.to_date
          rescue => e
            Rails.logger.warn "Could not parse due date: #{e.message}"
          end
        end

        card.save!

        # Map status to column
        column = find_or_create_column_for_status(board, status)
        if column
          card.update!(column: column)
        end

        # If status is "done" or "complete", close the card
        if ["done", "complete"].include?(status.downcase)
          card.close(user: system_user)
        end

        # Add list name as label (tag)
        if list_name.present?
          card.toggle_tag_with(list_name)
        end

        # Add priority as label if not normal
        priority = imported_task.priority
        if priority.present? && priority != "normal"
          card.toggle_tag_with("priority: #{priority}")
        end

        # Add tags from ClickUp
        tags_json = row["Tags"]
        if tags_json.present? && tags_json != "[]" && tags_json != "null"
          begin
            tags = JSON.parse(tags_json)
            tags.each do |tag_name|
              next if tag_name.blank?
              # Skip bug/feature tags as we already prefixed the title
              next if ["bug", "feature"].include?(tag_name.downcase)
              card.toggle_tag_with(tag_name)
            end
          rescue JSON::ParserError
            Rails.logger.warn "Could not parse tags: #{tags_json}"
          end
        end

        # Assign users (best effort - match by email or name)
        assignees_json = row["Assignees"]
        if assignees_json.present? && assignees_json != "[]" && assignees_json != "null"
          begin
            assignee_list = JSON.parse(assignees_json)
            assignee_list.each do |assignee_name|
              user = find_user_by_name_or_email(assignee_name)
              if user
                # Assign user if not already assigned
                unless card.assigned_to?(user)
                  # Set Current.user temporarily for assignment tracking
                  old_user = Current.user
                  Current.user = system_user
                  card.toggle_assignment(user)
                  Current.user = old_user
                end
              else
                Rails.logger.warn "Could not find user for assignee: #{assignee_name}"
              end
            end
          rescue JSON::ParserError
            Rails.logger.warn "Could not parse assignees: #{assignees_json}"
          end
        end

        # TODO: Import comments and attachments
        # Comments are in row["Comments"] (JSON array)
        # Attachments are in row["Attachments"] (JSON array)

        Rails.logger.debug "Created card #{card.number} from ClickUp task #{imported_task.external_id}"
        card
      end

      def extract_bug_feature_prefix(tags_json)
        return nil if tags_json.blank? || tags_json == "[]" || tags_json == "null"

        begin
          tags = JSON.parse(tags_json)
          tags.each do |tag|
            tag_lower = tag.to_s.downcase
            return "bug" if tag_lower == "bug"
            return "feature" if tag_lower == "feature"
          end
        rescue JSON::ParserError
          # Not JSON, check if it's a simple string
          tags_json_lower = tags_json.downcase
          return "bug" if tags_json_lower.include?("bug")
          return "feature" if tags_json_lower.include?("feature")
        end

        nil
      end

      def find_user_by_name_or_email(identifier)
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
end
