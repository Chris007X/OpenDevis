class BiddingRecommendationService
  def initialize(bidding_round)
    @bidding_round = bidding_round
  end

  def call
    responded = @bidding_round.bidding_requests
                              .where(status: "responded")
                              .includes(:artisan, :work_category)

    responded.group_by(&:work_category_id).transform_values do |requests|
      prices = requests.map { |r| r.price_total.to_f }
      requests.map { |req| score(req, prices.min, prices.max) }
              .sort_by { |s| -s[:score] }
    end
  end

  private

  def score(req, min_price, max_price)
    price_score = if max_price == min_price
                    1.0
                  else
                    1.0 - ((req.price_total.to_f - min_price) / (max_price - min_price))
                  end
    rating_score = (req.artisan.rating || 0).to_f / 5.0
    weighted = (0.6 * price_score) + (0.4 * rating_score)
    { request: req, score: weighted, price_score: price_score, rating_score: rating_score }
  end
end
