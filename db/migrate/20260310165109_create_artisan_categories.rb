class CreateArtisanCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :artisan_categories do |t|
      t.references :artisan, null: false, foreign_key: true
      t.references :work_category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :artisan_categories, [:artisan_id, :work_category_id], unique: true
  end
end
