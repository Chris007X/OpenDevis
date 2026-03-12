class AddPhotoUrlToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :photo_url, :text
  end
end
