class CreateMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :materials do |t|
      t.references :work_category, null: false, foreign_key: true
      t.string :brand
      t.string :reference
      t.decimal :public_price_exVAT
      t.string :unit
      t.integer :vat_rate

      t.timestamps
    end
  end
end
