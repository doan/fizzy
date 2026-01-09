class Board < ApplicationRecord
  include Accessible, AutoPostponing, Board::DefaultColumns, Board::Storage, Broadcastable, Cards, Entropic, Filterable, Publishable, ::Storage::Tracked, Triageable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  has_rich_text :public_description

  has_many :tags, -> { distinct }, through: :cards
  has_many :events
  has_many :webhooks, dependent: :destroy

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recently_accessed, -> { merge(Access.ordered_by_recently_accessed) }

  def total_tracked_hours_for_awaiting_triage
    card_ids = cards.awaiting_triage.pluck(:id)
    return 0.0 if card_ids.empty?
    TimeEntry.where(card_id: card_ids).sum(:hours) || 0.0
  end

  def total_tracked_hours_for_postponed
    card_ids = cards.postponed.pluck(:id)
    return 0.0 if card_ids.empty?
    TimeEntry.where(card_id: card_ids).sum(:hours) || 0.0
  end

  def total_tracked_hours_for_closed
    card_ids = cards.closed.pluck(:id)
    return 0.0 if card_ids.empty?
    TimeEntry.where(card_id: card_ids).sum(:hours) || 0.0
  end
end
