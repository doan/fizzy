class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :creator, class_name: "User"
  belongs_to :source, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :ordered, -> { order(read_at: :desc, created_at: :desc) }

  after_create_commit :broadcast_unread

  def self.read_all
    update!(read_at: Time.current)
  end

  def read
    update!(read_at: Time.current)
  end

  def read?
    read_at.present?
  end

  def target
    if source.is_a?(Event)
      source.target
    else
      source
    end
  end

  private
    def broadcast_unread
      broadcast_prepend_later_to user, :notifications, target: "notifications"
    end
end
