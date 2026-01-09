module Card::TimeTrackable
  extend ActiveSupport::Concern

  included do
    has_many :time_entries, dependent: :destroy
  end

  def total_time_hours
    time_entries.sum(:hours) || 0.0
  end

  def time_entries_for(user)
    time_entries.for_user(user).recent
  end

  def add_time_entry(hours:, user: Current.user, notes: nil)
    old_user = Current.user
    Current.user = user

    time_entry = time_entries.create!(
      hours: hours,
      user: user,
      account: account,
      notes: notes
    )

    # Create a comment about this time entry
    create_time_entry_comment(time_entry, notes)

    time_entry
  ensure
    Current.user = old_user
  end

  private
    def create_time_entry_comment(time_entry, notes_text)
      user_name = time_entry.user.familiar_name
      hours_text = "#{time_entry.hours}h"
      
      comment_body = if notes_text.present?
        "#{user_name} added #{hours_text} for #{notes_text}"
      else
        "#{user_name} added #{hours_text}"
      end

      comments.create!(
        body: comment_body,
        creator: time_entry.user
      )
    end
end
