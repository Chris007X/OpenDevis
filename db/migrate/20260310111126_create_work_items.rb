class CreateWorkItems < ActiveRecord::Migration[8.1]
  def change
    create_table :work_items do |t|
      t.references :room, null: false, foreign_key: true
      t.references :work_category, null: false, foreign_key: true
      t.references :material, null: false, foreign_key: true
      t.string :label
      t.decimal :quantity
      t.string :unit
      t.decimal :unit_price_exVAT
      t.integer :standing_level
      t.integer :vat_rate

      t.timestamps
    end
  end
end
