class RemoveStandingLevelFromReferencePrices < ActiveRecord::Migration[8.1]
  def change
    remove_index :reference_prices, name: "idx_ref_prices_cat_standing_sort"
    remove_index :reference_prices, [:category_slug, :standing_level]
    remove_column :reference_prices, :standing_level, :integer, null: false

    add_index :reference_prices, :category_slug
    add_index :reference_prices, [:category_slug, :sort_order], name: "idx_ref_prices_cat_sort"
  end
end
