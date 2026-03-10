class FixDecimalPrecisionAndRemoveDeletedAt < ActiveRecord::Migration[8.1]
  def change
    remove_column :projects, :deleted_at, :datetime

    change_column :materials, :public_price_exVAT, :decimal, precision: 10, scale: 2
    change_column :projects, :total_exVAT, :decimal, precision: 10, scale: 2
    change_column :projects, :total_incVAT, :decimal, precision: 10, scale: 2
    change_column :projects, :total_surface_sqm, :decimal, precision: 10, scale: 2
    change_column :rooms, :surface_sqm, :decimal, precision: 10, scale: 2
    change_column :rooms, :perimeter_lm, :decimal, precision: 10, scale: 2
    change_column :rooms, :wall_height_m, :decimal, precision: 10, scale: 2
    change_column :work_items, :quantity, :decimal, precision: 10, scale: 3
    change_column :work_items, :unit_price_exVAT, :decimal, precision: 10, scale: 2
  end
end
