class Collections::ColumnsController < ApplicationController
  include ActionView::RecordIdentifier, CollectionScoped

  before_action :set_column, only: [:show, :update, :destroy]

  def show
    set_page_and_extract_portion_from @column.cards.active.reverse_chronologically
  end

  def create
    @column = @collection.columns.create!(column_params)
    render turbo_stream: turbo_stream.before("closed-cards", partial: "collections/show/column", method: :morph, locals: { column: @column })
  end

  def update
    @column.update!(column_params)
    render turbo_stream: turbo_stream.replace(dom_id(@column), partial: "collections/show/column", method: :morph, locals: { column: @column })
  end

  def destroy
    @column.destroy
    render turbo_stream: turbo_stream.remove(dom_id(@column))
  end

  private
    def set_column
      @column = @collection.columns.find(params[:id])
    end

    def column_params
      params.require(:column).permit(:name)
    end
end
