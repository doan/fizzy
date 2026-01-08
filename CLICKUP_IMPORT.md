# ClickUp Import to Fizzy

## Overview

This implementation allows you to import data from ClickUp into Fizzy. The import follows a specific mapping structure:

### Mapping Structure

- **ClickUp Folders** → **Fizzy Boards** (long-lived areas of work)
- **ClickUp Lists** → **Fizzy Labels (tags)** (contextual, not structural)
- **ClickUp Tasks** → **Fizzy Cards**
- **ClickUp Status** → **Fizzy Columns/Status** (Open, In Progress, In Review, Blocked, Done)
- **Bug/Feature tags** → **Title prefix** `[bug]` or `[feature]`
- **Priority** → **Label** (priority: urgent, priority: high, etc.)
- Tracks imported tasks in `ImportedClickupTask` model

## What Was Implemented

### 1. Database Models
- `ImportedClickupTask` - Tracks imported ClickUp tasks with metadata
- Migration includes `account_id` for multi-tenancy
- Links to created `Card` via `card_id` for tracking

### 2. Import Service
- `Import::ClickupImporter` - Main service class that:
  - Fetches folders, lists, and tasks from ClickUp API
  - Creates Fizzy boards from ClickUp folders
  - Creates Fizzy cards from ClickUp tasks
  - Stores import metadata for tracking

### 3. Import Context
- `Import::Context` - Provides account context for imports
- Uses "Blue Otter's Fizzy" account in production
- Falls back to first account in development

### 4. Rake Task
- `rake clickup:import[api_token,space_id]` - Runs the full import

## Usage

### CSV Import (Recommended)

The CSV importer matches the agreed specification and is the recommended approach.

**Prerequisites:**
1. Export your ClickUp data as CSV from ClickUp
2. Ensure the CSV has the required columns (Task ID, Task Name, Folder Name/Path, List Name, Status, etc.)

**Running the CSV Import:**

**Option 1: Helper scripts (Recommended)**
```bash
# Import to local development database
bin/import_clickup_local [path/to/file.csv]

# Import to production server
bin/import_clickup_production [path/to/file.csv]
```

**Option 2: Rake task (local only)**
```bash
rake clickup:import_csv[path/to/clickup_export.csv]
```

**Option 3: Environment variable**
```bash
CLICKUP_CSV_PATH=path/to/clickup_export.csv rake clickup:import_csv
```

**Option 4: In Rails console**
```ruby
importer = Import::ClickupCsvImporter.new(csv_path: "path/to/clickup_export.csv")
result = importer.import_all
# Returns: { imported: count, skipped: count, errors: count }
```

### API Import (Alternative)

If you prefer to import directly from the ClickUp API:

1. **Get ClickUp API Token**
   - Go to ClickUp Settings → Apps → API
   - Generate a personal API token
   - Copy the token (starts with `pk_`)

2. **Get ClickUp Space ID**
   - In ClickUp, go to your Space
   - The Space ID is in the URL: `https://app.clickup.com/{space_id}/...`

**Running the API Import:**
```bash
rake clickup:import_api[your_api_token,your_space_id]
# or
CLICKUP_API_TOKEN=your_token CLICKUP_SPACE_ID=your_space_id rake clickup:import_api
```

### What Gets Imported (CSV Import)

- **Folders** → Each ClickUp folder becomes a Fizzy board
- **Lists** → List names become labels (tags) on cards
- **Tasks** → Each ClickUp task becomes a Fizzy card with:
  - Title from task name (with [bug] or [feature] prefix if applicable)
  - Description from task content
  - Status mapped to Fizzy columns:
    - `backlog` / `to do` → Open (awaiting triage)
    - `in progress` → In Progress column
    - `review` → In Review column
    - `blocked` → Blocked column
    - `done` / `complete` → Done column (card is closed)
  - List name as a label (tag)
  - Priority as a label (priority: urgent, priority: high, etc.)
  - Tags from ClickUp (except bug/feature which become title prefixes)
  - Assignees (matched by email or name)
  - Due dates (stored in `due_on` field)
  - Created dates (preserved from ClickUp)

### Import Tracking

All imported tasks are tracked in `ImportedClickupTask`:
- Prevents duplicate imports (skips already imported tasks)
- Stores raw ClickUp payload for reference
- Links to created Fizzy card via `card_id`

### Querying Imported Data

```ruby
# Find all imported tasks for an account
account = Account.find_by(name: "Blue Otter's Fizzy")
ImportedClickupTask.for_account(account)

# Find tasks that were successfully imported (have cards)
ImportedClickupTask.imported

# Find tasks that failed to import
ImportedClickupTask.pending
```

## API Limitations

The current implementation:
- Fetches first 100 tasks per list (ClickUp pagination)
- Does not import comments or attachments
- Does not map ClickUp statuses to Fizzy columns
- Does not import custom fields (except sprint label extraction)

## Future Enhancements

Potential improvements:
1. **Pagination** - Handle lists with >100 tasks
2. **Status Mapping** - Map ClickUp statuses to Fizzy columns
3. **Comments** - Import task comments as card comments
4. **Attachments** - Import task attachments
5. **Custom Fields** - Better handling of ClickUp custom fields
6. **Incremental Updates** - Update existing cards instead of skipping
7. **Error Handling** - Better error reporting and retry logic

## Files Created/Modified

- `app/models/imported_clickup_task.rb` - Model for tracking imports
- `app/services/import/clickup_csv_importer.rb` - CSV-based import service (recommended)
- `app/services/import/clickup_importer.rb` - API-based import service
- `app/services/import/context.rb` - Account context helper
- `lib/tasks/clickup_import.rake` - Rake tasks for running imports
- `db/migrate/20260108094154_create_imported_clickup_tasks.rb` - Initial migration
- `db/migrate/20260108120000_add_card_to_imported_clickup_tasks.rb` - Card reference migration

## Notes

- The importer uses the system user as the creator for imported boards/cards
- All imports are scoped to the account from `Import::Context`
- The import is idempotent - running it multiple times won't create duplicates
- ClickUp API rate limits apply (100 requests per minute by default)
