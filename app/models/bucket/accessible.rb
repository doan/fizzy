module Bucket::Accessible
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :delete_all do
      def revise(granted: [], revoked: [])
        transaction do
          grant_to granted
          revoke_from revoked
        end
      end

      private
        def grant_to(users)
          Access.insert_all Array(users).collect { |user| { bucket_id: proxy_association.owner.id, user_id: user.id } }
        end

        def revoke_from(users)
          destroy_by user: users
        end
    end

    has_many :users, through: :accesses

    after_create -> { accesses.grant_to(creator) }
  end
end
