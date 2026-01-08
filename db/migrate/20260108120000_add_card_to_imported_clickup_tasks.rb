class AddCardToImportedClickupTasks < ActiveRecord::Migration[8.2]
  def change
    add_reference :imported_clickup_tasks, :card, null: true, foreign_key: true, type: :uuid
    add_index :imported_clickup_tasks, :card_id
  end
end
