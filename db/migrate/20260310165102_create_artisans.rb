class CreateArtisans < ActiveRecord::Migration[8.1]
  def change
    create_table :artisans do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :company_name
      t.string :postcode, null: false
      t.decimal :rating, precision: 3, scale: 2
      t.text :certifications
      t.string :portfolio_url
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :artisans, :email, unique: true
  end
end
