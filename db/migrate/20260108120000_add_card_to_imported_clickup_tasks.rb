class AddCardToImportedClickupTasks < ActiveRecord::Migration[8.2]
  def change
    unless column_exists?(:imported_clickup_tasks, :card_id)
      add_reference :imported_clickup_tasks, :card, null: true, foreign_key: true, type: :uuid
    end
    add_index :imported_clickup_tasks, :card_id unless index_exists?(:imported_clickup_tasks, :card_id)
  end
end
