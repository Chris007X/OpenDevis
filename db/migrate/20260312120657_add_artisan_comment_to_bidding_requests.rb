class AddArtisanCommentToBiddingRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :bidding_requests, :artisan_comment, :text
  end
end
