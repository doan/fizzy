class Cards::TriagesController < ApplicationController
  include CardScoped

  def create
    @old_column = @card.column
    capture_card_location
    column = @card.board.columns.find(params[:column_id])
    @card.triage_into(column)
    @new_column = @card.column
    refresh_stream_if_needed

    # Check if we should prompt for time entry
    @should_prompt_for_time = should_prompt_for_time?(@old_column, @new_column)
    
    # Debug logging (remove in production)
    if Rails.env.development?
      Rails.logger.debug "Time entry prompt check: old_column=#{@old_column&.name}, new_column=#{@new_column&.name}, should_prompt=#{@should_prompt_for_time}"
    end

    respond_to do |format|
      format.html { redirect_to @card }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @card.send_back_to_triage

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  private
    def should_prompt_for_time?(old_column, new_column)
      return false unless old_column && new_column

      old_name = old_column.name.downcase
      new_name = new_column.name.downcase

      # Check if moving from "in progress" to "verifying" or "done"
      (old_name.include?("progress") || old_name.include?("in progress")) &&
        (new_name.include?("verifying") || new_name.include?("done") || new_name == "done")
    end
end
