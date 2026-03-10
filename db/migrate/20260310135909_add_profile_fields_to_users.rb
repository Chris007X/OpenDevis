class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :full_name, :string
    add_column :users, :phone, :string
    add_column :users, :location, :string
    add_column :users, :auth_provider, :string, default: "email"
  end
end
