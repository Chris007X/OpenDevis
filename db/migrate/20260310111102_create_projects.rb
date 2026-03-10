class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.text :property_url
      t.decimal :total_surface_sqm
      t.integer :room_count
      t.string :location_zip
      t.string :energy_rating
      t.decimal :total_exVAT
      t.decimal :total_incVAT
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
