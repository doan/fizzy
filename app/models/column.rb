class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  after_save_commit    -> { cards.touch_all }, if: -> { saved_change_to_name? || saved_change_to_color? }
  after_destroy_commit -> { board.cards.touch_all }

  def total_tracked_hours
    card_ids = cards.active.pluck(:id)
    return 0.0 if card_ids.empty?
    TimeEntry.where(card_id: card_ids).sum(:hours) || 0.0
  end
end
