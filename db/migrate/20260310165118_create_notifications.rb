class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body
      t.boolean :read, default: false, null: false

      t.timestamps
    end

    add_index :notifications, [:user_id, :read]
  end
end
