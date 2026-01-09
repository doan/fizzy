# app/services/import/clickup_importer.rb

require "net/http"
require "json"
require "uri"

module Import
  class ClickupImporter
    CLICKUP_API_BASE = "https://api.clickup.com/api/v2"

    attr_reader :account, :api_token, :space_id, :system_user

    def initialize(account: nil, api_token:, space_id:)
      @account = account || Import::Context.account
      @api_token = api_token
      @space_id = space_id
      @system_user = @account.system_user
    end

    def import_all
      Rails.logger.info "Starting ClickUp import for account: #{account.name}"

      folders = fetch_folders
      Rails.logger.info "Found #{folders.size} folders in ClickUp space"

      folders.each do |folder_data|
        import_folder(folder_data)
      end

      Rails.logger.info "ClickUp import completed"
    end

    def import_folder(folder_data)
      folder_name = folder_data["name"]
      folder_id = folder_data["id"]

      Rails.logger.info "Importing folder: #{folder_name}"

      # Find or create board for this folder
      board = find_or_create_board(folder_name)

      # Fetch lists in this folder
      lists = fetch_lists(folder_id)
      Rails.logger.info "Found #{lists.size} lists in folder #{folder_name}"

      lists.each do |list_data|
        import_list(board, list_data, folder_name)
      end
    end

    def import_list(board, list_data, folder_name)
      list_name = list_data["name"]
      list_id = list_data["id"]

      Rails.logger.info "Importing list: #{list_name}"

      # Fetch tasks from this list
      tasks = fetch_tasks(list_id)
      Rails.logger.info "Found #{tasks.size} tasks in list #{list_name}"

      tasks.each do |task_data|
        import_task(board, task_data, folder_name, list_name)
      end
    end

    def import_task(board, task_data, folder_name, list_name)
      task_id = task_data["id"]
      task_name = task_data["name"] || "Untitled"

      # Check if already imported
      existing = ImportedClickupTask.find_by(external_id: task_id, account: account)
      if existing
        Rails.logger.debug "Task #{task_id} already imported, skipping"
        return
      end

      # Create or update imported task record
      imported_task = ImportedClickupTask.find_or_initialize_by(
        external_id: task_id,
        account: account
      )

      imported_task.assign_attributes(
        folder_name: folder_name,
        list_name: list_name,
        title: task_name,
        description: extract_description(task_data),
        status: task_data["status"]&.dig("status") || "unknown",
        priority: task_data["priority"]&.dig("priority")&.to_s || "normal",
        assignees: extract_assignees(task_data),
        sprint_label: extract_sprint_label(task_data),
        raw_payload: task_data
      )

      imported_task.save!

      # Create Fizzy card from ClickUp task
      create_card_from_task(board, task_data, imported_task)
    end

    private

      def fetch_folders
        response = http_get("/space/#{space_id}/folder")
        response["folders"] || []
      rescue => e
        Rails.logger.error "Error fetching folders: #{e.message}"
        []
      end

      def fetch_lists(folder_id)
        response = http_get("/folder/#{folder_id}/list")
        response["lists"] || []
      rescue => e
        Rails.logger.error "Error fetching lists for folder #{folder_id}: #{e.message}"
        []
      end

      def fetch_tasks(list_id)
        # ClickUp API returns tasks with pagination
        # For now, fetch first page (100 tasks)
        # TODO: Add pagination support for large lists
        response = http_get("/list/#{list_id}/task?archived=false&page=0")
        response["tasks"] || []
      rescue => e
        Rails.logger.error "Error fetching tasks for list #{list_id}: #{e.message}"
        []
      end

      def find_or_create_board(folder_name)
        board = account.boards.find_by(name: folder_name)
        return board if board

        # Create board with system user as creator
        account.boards.create!(
          name: folder_name,
          creator: system_user,
          account: account
        )
      end

      def create_card_from_task(board, task_data, imported_task)
        # Check if card already exists for this imported task
        # We could add a card_id reference to ImportedClickupTask later
        # For now, create new card

        # Extract creator from ClickUp API response
        creator = extract_creator_from_task_data(task_data)

        # Set Current.user for event tracking
        old_current_user = Current.user
        Current.user = creator

        card = board.cards.build(
          account: account,
          board: board,
          creator: creator,
          title: imported_task.title,
          status: "published"
        )

        # Set description if present
        if imported_task.description.present?
          card.description = imported_task.description
        end

        # Set created_at from ClickUp if available
        if task_data["date_created"]
          begin
            created_timestamp = task_data["date_created"].to_i / 1000 # Convert ms to seconds
            card.created_at = Time.at(created_timestamp)
          rescue => e
            Rails.logger.warn "Could not parse created date: #{e.message}"
          end
        end

        # Map ClickUp status to Fizzy column if possible
        # ClickUp statuses are custom, so we'll just create the card
        # and let it go to the default column

        card.save!

        # Link the imported task to the created card
        imported_task.update!(card: card)

        # Map ClickUp priority to Fizzy color if needed
        # Priority mapping could be: urgent -> red, high -> orange, etc.

        Rails.logger.debug "Created card #{card.number} from ClickUp task #{imported_task.external_id}"
        card
      ensure
        # Restore Current.user
        Current.user = old_current_user
      end

      def extract_description(task_data)
        description = task_data["description"] || ""
        
        # ClickUp description can be markdown or HTML
        # ActionText will handle it, but we might want to clean it up
        description
      end

      def extract_assignees(task_data)
        assignees = task_data["assignees"] || []
        assignees.map { |a| a["username"] || a["email"] }.compact.join(", ")
      end

      def extract_sprint_label(task_data)
        # ClickUp custom fields might contain sprint info
        # This is a placeholder - adjust based on your ClickUp setup
        task_data.dig("custom_fields")&.find { |f| f["name"]&.downcase&.include?("sprint") }&.dig("value")&.to_s
      end

      def extract_creator_from_task_data(task_data)
        # ClickUp API provides creator info in the task data
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

        # Fallback to system user if we can't find a match
        system_user
      end

      def http_get(path)
        uri = URI("#{CLICKUP_API_BASE}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = api_token
        request["Content-Type"] = "application/json"

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "ClickUp API error: #{response.code} #{response.message}"
        end

        JSON.parse(response.body)
      end
  end
end
