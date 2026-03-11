class CreateFinalSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :final_selections do |t|
      t.references :bidding_round, null: false, foreign_key: true
      t.references :work_category, null: false, foreign_key: true
      t.references :bidding_request, null: false, foreign_key: true
      t.boolean :ai_recommended, default: false, null: false
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :final_selections, [:bidding_round_id, :work_category_id], unique: true
  end
end
