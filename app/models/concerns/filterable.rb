module Filterable
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :filters

    after_update { filters.touch_all }
    before_destroy :remove_from_filters
  end

  private
    # FIXME: This is too inefficient to have part of a destroy transaction.
    # Need to find a way to use a job or a single query.
    def remove_from_filters
      filters.find_each do |filter|
        begin
          filter.resource_removed self
        rescue => e
          Rails.logger.error "Error removing #{self.class.name} #{id} from filter #{filter.id}: #{e.message}"
          # Continue processing other filters even if one fails
        end
      end
    end
end
