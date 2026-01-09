module Board::AutoPostponing
  extend ActiveSupport::Concern

  included do
    before_create :set_default_auto_postpone_period
  end

  private
    DEFAULT_AUTO_POSTPONE_PERIOD = 30.days

    def set_default_auto_postpone_period
      # Only set default if board doesn't have its own entropy and account doesn't have one either
      # The entropy method falls back to account.entropy, so we check the association directly
      board_entropy = association(:entropy).loaded? ? association(:entropy).target : nil
      account_entropy = account&.entropy
      
      # If board has no entropy and account has no entropy, create board entropy with default
      if board_entropy.nil? && account_entropy.nil?
        build_entropy(auto_postpone_period: DEFAULT_AUTO_POSTPONE_PERIOD)
      end
    end
end
