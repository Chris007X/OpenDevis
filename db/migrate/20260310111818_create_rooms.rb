class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name
      t.decimal :surface_sqm
      t.decimal :perimeter_lm
      t.decimal :wall_height_m

      t.timestamps
    end
  end
end
