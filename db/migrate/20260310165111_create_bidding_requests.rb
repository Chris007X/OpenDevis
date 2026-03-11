class CreateBiddingRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :bidding_requests do |t|
      t.references :bidding_round, null: false, foreign_key: true
      t.references :work_category, null: false, foreign_key: true
      t.references :artisan, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.decimal :price_total, precision: 10, scale: 2
      t.string :response_method
      t.datetime :responded_at
      t.string :token, null: false
      t.datetime :sent_at
      t.bigint :replaced_by_id

      t.timestamps
    end

    add_index :bidding_requests, [:bidding_round_id, :work_category_id, :artisan_id], unique: true,
              name: "index_bidding_requests_on_round_category_artisan"
    add_index :bidding_requests, :token, unique: true
  end
end
