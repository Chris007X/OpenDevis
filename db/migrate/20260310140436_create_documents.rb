class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :project, null: false, foreign_key: true
      t.string :file_type
      t.text :file_url
      t.string :file_name
      t.datetime :uploaded_at

      t.timestamps
    end
  end
end
