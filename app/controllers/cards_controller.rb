class CardsController < ApplicationController
  include FilterScoped

  before_action :set_board, only: %i[ create ]
  before_action :set_card, only: %i[ show edit update destroy ]
  before_action :ensure_permission_to_administer_card, only: %i[ destroy ]

  def index
    set_page_and_extract_portion_from @filter.cards
  end

  def create
    respond_to do |format|
      format.html do
        card = Current.user.draft_new_card_in(@board)
        redirect_to card
      end

      format.json do
        card = @board.cards.create! card_params.merge(creator: Current.user, status: "published")
        head :created, location: card_path(card, format: :json)
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    @card.update! card_params

    respond_to do |format|
      format.turbo_stream
      format.json { render :show }
    end
  end

  def destroy
    # Capture location and DOM IDs before destroying
    @board = @card.board
    @source_column = @card.column
    @was_in_stream = @card.awaiting_triage?
    @was_postponed = @card.postponed?
    @was_closed = @card.closed?
    @card_article_id = dom_id(@card, :article)
    @card_container_id = dom_id(@card, :card_container)
    
    @card.destroy!
    
    # Set up page for stream if needed
    if @was_in_stream
      set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first.preloaded
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @board, notice: "Card deleted" }
      format.json { head :no_content }
    end
  end

  private
    def set_board
      @board = Current.user.boards.find params[:board_id]
    end

    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:id])
    end

    def ensure_permission_to_administer_card
      head :forbidden unless Current.user.can_administer_card?(@card)
    end

    def card_params
      params.expect(card: [ :title, :description, :image, :created_at, :last_active_at ])
    end
end
