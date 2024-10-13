class Bubble::Thread::Rollup
  def initialize(thread, entries, first_position: false)
    @thread = thread
    @entries = entries
    @first_position = first_position
  end

  def body
    collapsed_entries.map { |entry, chunk_size| summarize(entry, chunk_size) }.to_sentence.upcase_first
  end

  def to_partial_path
    "bubbles/threads/rollup"
  end

  private
    attr_reader :thread, :entries, :first_position

    delegate :time_ago_in_words, to: "ApplicationController.helpers", private: true

    def collapsed_entries
      sorted_entries.chunk_while { |a, b| repeated_boosts?(a, b) }.map { |chunk| [ chunk.last, chunk.size ] }
    end

    def sorted_entries
      entries.sort_by do |entry|
        case entry.action
        when "created"  then [ 1, entry.created_at ]
        when "assigned" then [ 2, entry.created_at ]
        when "boosted"  then [ 3, entry.creator, entry.created_at ]
        end
      end
    end

    def repeated_boosts?(a, b)
      a.action == "boosted" && a.slice(:action, :creator_id) == b.slice(:action, :creator_id)
    end

    def summarize(entry, chunk_size)
      case entry.action
      when "created"
        "added by #{entry.creator.name} #{time_ago_in_words(entry.created_at)} ago"
      when "assigned"
        summary = "assigned to #{entry.assignee_names.to_sentence}"
        summary += " #{time_ago_in_words(entry.created_at)} ago" unless first_position?
        summary
      when "boosted"
        "#{entry.creator.name} +#{chunk_size}"
      end
    end

    def first_position?
      first_position
    end
end
