class CreateImportedClickupTasks < ActiveRecord::Migration[8.2]
  def change
    create_table :imported_clickup_tasks, id: :uuid do |t|
      t.string :external_id
      t.string :folder_name
      t.string :list_name
      t.string :title
      t.text :description
      t.string :status
      t.string :priority
      t.text :assignees
      t.string :sprint_label
      t.json :raw_payload

      t.timestamps
    end
  end
end
