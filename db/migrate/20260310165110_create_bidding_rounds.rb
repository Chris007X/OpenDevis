class CreateBiddingRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :bidding_rounds do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.integer :standing_level, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :deadline, null: false

      t.timestamps
    end
  end
end
