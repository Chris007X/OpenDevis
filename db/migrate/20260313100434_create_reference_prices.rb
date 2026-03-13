class CreateReferencePrices < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_prices do |t|
      t.string  :category_slug,       null: false
      t.string  :label,               null: false
      t.string  :unit,                null: false
      t.decimal :supply_price_exVAT,  precision: 10, scale: 2, null: false, default: 0
      t.decimal :labor_price_exVAT,   precision: 10, scale: 2, null: false, default: 0
      t.integer :vat_rate,            null: false, default: 10
      t.integer :standing_level,      null: false
      t.string  :quantity_formula,    null: false, default: "surface"
      t.string  :applicable_rooms
      t.integer :sort_order,          null: false, default: 0
      t.timestamps
    end

    add_index :reference_prices, [:category_slug, :standing_level]
    add_index :reference_prices, [:category_slug, :standing_level, :sort_order],
              name: "idx_ref_prices_cat_standing_sort"
  end
end
