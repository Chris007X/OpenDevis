class AddDeviseToArtisans < ActiveRecord::Migration[8.1]
  def change
    add_column :artisans, :encrypted_password, :string, null: false, default: ""
    add_column :artisans, :reset_password_token, :string
    add_column :artisans, :reset_password_sent_at, :datetime
    add_column :artisans, :remember_created_at, :datetime
    add_index :artisans, :reset_password_token, unique: true
  end
end
