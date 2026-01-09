class CreateTimeEntries < ActiveRecord::Migration[8.2]
  def change
    create_table :time_entries, id: :uuid do |t|
      t.references :card, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.decimal :hours, precision: 10, scale: 2, null: false
      t.text :notes

      t.timestamps
    end

    add_index :time_entries, [:card_id, :user_id]
  end
end
