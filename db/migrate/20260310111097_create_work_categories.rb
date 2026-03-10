class CreateWorkCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :work_categories do |t|
      t.string :name
      t.string :slug

      t.timestamps
    end
  end
end
