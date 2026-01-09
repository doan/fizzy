namespace :clickup do
  desc "Refresh event cache for cards that had titles updated from Untitled"
  task :refresh_event_cache => :environment do
    account = Import::Context.account
    system_user = account.system_user
    old_current_user = Current.user
    Current.user = system_user

    puts "🔄 Refreshing event cache for updated cards..."
    
    # Find all cards that were imported from ClickUp and have events
    # We'll touch all events for imported cards to expire their cache
    imported_card_ids = ImportedClickupTask
      .where(account: account)
      .where.not(card_id: nil)
      .pluck(:card_id)
    
    puts "Found #{imported_card_ids.count} imported cards"
    
    # Find all events for these cards
    events = Event
      .joins("INNER JOIN cards ON events.eventable_type = 'Card' AND events.eventable_id = cards.id")
      .where(cards: { id: imported_card_ids })
      .where(account: account)
    
    puts "Found #{events.count} events to refresh"
    
    # Touch events to expire cache
    # The cache key includes the event's updated_at timestamp
    updated_count = 0
    events.find_each do |event|
      event.touch
      updated_count += 1
      puts "  ✓ Refreshed event #{event.id} for card ##{event.card.number}" if updated_count % 100 == 0
    end
    
    Current.user = old_current_user
    
    puts ""
    puts "✅ Cache refresh completed!"
    puts "  Refreshed #{updated_count} events"
    puts ""
    puts "Note: The activity feed should now show updated card titles."
    puts "You may need to refresh your browser to see the changes."
  end
end
