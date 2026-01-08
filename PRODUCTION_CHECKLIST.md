# 🚀 Production Deployment Checklist

## Before Deploying ClickUp Import

### 1. ✅ GitHub Container Registry (GHCR) Authentication
**Status: NOT READY** - Placeholder token still in `.kamal/secrets`

**Required Actions:**
1. Create GitHub Personal Access Token with these scopes:
   - `read:packages`
   - `write:packages`
   - `repo` (full control of private repositories)

2. Update `.kamal/secrets`:
   ```bash
   # Replace the placeholder
   KAMAL_REGISTRY_PASSWORD=ghp_your_real_token_here
   ```

3. Test authentication:
   ```bash
   docker login ghcr.io -u doan -p your_token
   kamal app details  # Should work without auth errors
   ```

### 2. ✅ Code is Ready
**Status: READY**
- All import code committed and pushed
- Successfully tested locally (4,629 tasks imported)
- Helper scripts created

### 3. ✅ CSV Data
**Status: READY**
- File: `25514952AgBalQd.csv` (2.7MB, 4,635 tasks)
- Ready to upload to production server

### 4. ✅ Production Account
**Status: READY (Assumed)**
- Import context looks for "Blue Otter's Fizzy" account
- System user should exist in production

## Deployment Steps

### Step 1: Fix GHCR Authentication
```bash
# 1. Create GitHub PAT (see .kamal/GHCR_SETUP.md)
# 2. Update .kamal/secrets with real token
# 3. Test: kamal app details
```

### Step 2: Deploy Code to Production
```bash
kamal deploy
```

### Step 3: Run Database Migrations
```bash
kamal app exec "cd /rails && bin/rails db:migrate"
```

### Step 4: Upload and Import Data
```bash
# Upload CSV
scp 25514952AgBalQd.csv deploy@178.128.28.249:/tmp/

# Run import
bin/import_clickup_production 25514952AgBalQd.csv
```

## Expected Results

- **5 boards created** from ClickUp folders
- **~4,629 cards created** from ClickUp tasks
- **Statuses mapped** to Fizzy columns (Open, In Progress, etc.)
- **Labels added** for lists, priorities, etc.
- **Bug/feature prefixes** added to titles

## Verification

After import, check:
- `https://fizzy.teamblueotter.com` - New boards and cards visible
- Board names match ClickUp folder names
- Card counts match expected numbers
- Statuses and labels applied correctly

## Rollback Plan

If issues occur:
```bash
# Stop the app
kamal app stop

# Rollback deployment
kamal deploy --rollback

# Or manually remove imported data
kamal app exec "cd /rails && bin/rails console"
# Then: ImportedClickupTask.destroy_all; Card.where(...).destroy_all
```