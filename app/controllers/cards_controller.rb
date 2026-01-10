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
    begin
      @board = @card.board
      unless @board
        Rails.logger.error "Card #{@card.number} has no board association"
        respond_to do |format|
          format.turbo_stream { render turbo_stream: "", status: :unprocessable_entity }
          format.html { redirect_to root_path, alert: "Card has no board" }
          format.json { render json: { error: "Card has no board" }, status: :unprocessable_entity }
        end
        return
      end
      
      source_column_id = @card.column_id
      @was_in_stream = @card.awaiting_triage?
      @was_postponed = @card.postponed?
      @was_closed = @card.closed?
      @card_article_id = dom_id(@card, :article)
      @card_container_id = dom_id(@card, :card_container)
    rescue => e
      Rails.logger.error "Error capturing card state before deletion: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: "", status: :unprocessable_entity }
        format.html { redirect_to root_path, alert: "Error preparing card deletion" }
        format.json { render json: { error: "Error preparing card deletion" }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      @card.destroy!
    rescue => e
      Rails.logger.error "Error destroying card #{@card.number}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.turbo_stream { render turbo_stream: "", status: :unprocessable_entity }
        format.html { redirect_to @board || root_path, alert: "Error deleting card: #{e.message}" }
        format.json { render json: { error: "Failed to delete card: #{e.message}" }, status: :unprocessable_entity }
      end
      return
    end
    
    # Reload board and column from database after card is destroyed to get fresh associations
    # This ensures associations are up to date when rendering partials
    begin
      @board.reload
      
      if source_column_id
        # Find and reload the column to clear any cached associations
        @source_column = @board.columns.find_by(id: source_column_id)
        @source_column&.association(:cards).reset if @source_column
      else
        @source_column = nil
      end
      
      # Set up page for stream if needed
      if @was_in_stream
        begin
          set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first.preloaded
        rescue => e
          Rails.logger.error "Error setting up page for stream: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          @was_in_stream = false # Fall back to not rendering stream
        end
      end
    rescue => e
      Rails.logger.error "Error reloading board/column after card deletion: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Continue anyway - card is already deleted
      @source_column = nil
      @was_in_stream = false
      @was_postponed = false
      @was_closed = false
    end

    respond_to do |format|
      format.turbo_stream do
        begin
          render :destroy
        rescue => e
          Rails.logger.error "Error rendering turbo_stream for card deletion: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render turbo_stream: "", status: :unprocessable_entity
        end
      end
      format.html { redirect_to @board, notice: "Card deleted" }
      format.json { head :no_content }
    end
  rescue => e
    Rails.logger.error "Unexpected error in destroy action: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: "", status: :unprocessable_entity }
      format.html { redirect_to @board || root_path, alert: "Error deleting card" }
      format.json { render json: { error: "Failed to delete card" }, status: :unprocessable_entity }
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
