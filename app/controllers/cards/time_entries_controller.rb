class Cards::TimeEntriesController < ApplicationController
  include CardScoped

  def new
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end

  def create
    @time_entry = @card.add_time_entry(
      hours: time_entry_params[:hours],
      notes: time_entry_params[:notes]
    )
    
    # Reload card to get the newly created comment
    @card.reload
    @comment = @card.comments.order(created_at: :desc).first

    respond_to do |format|
      format.html { redirect_to @card, notice: "Time logged successfully" }
      format.turbo_stream
      format.json { head :created, location: card_path(@card, format: :json) }
    end
  rescue => e
    Rails.logger.error "Error creating time entry: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      format.html { redirect_to @card, alert: "Failed to log time: #{e.message}" }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("time-entry-form", partial: "cards/time_entries/form", locals: { card: @card }) }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  private
    def time_entry_params
      params.expect(time_entry: [ :hours, :notes ])
    end
end
