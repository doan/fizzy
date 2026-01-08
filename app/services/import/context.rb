# app/services/import/context.rb

module Import
  module Context
    PRODUCTION_ACCOUNT_NAME = "Blue Otter's Fizzy"

    def self.account
      @account ||= begin
        if Rails.env.production?
          Account.find_by!(name: PRODUCTION_ACCOUNT_NAME)
        else
          Account.first or raise "No accounts found"
        end
      end
    end
  end
end
