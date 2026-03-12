class AddNameToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :name, :string
  end
end
