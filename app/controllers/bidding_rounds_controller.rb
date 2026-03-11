# rubocop:disable Metrics/ClassLength
class BiddingRoundsController < ApplicationController
  before_action :set_project
  before_action :set_bidding_round, only: %i[show send_requests select_artisans update_artisans
                                             review_responses confirm_selections final_quote
                                             select_replacement replace_artisan]

  def new
    authorize :bidding_round, :new?
    @bidding_round = BiddingRound.new
    @standing_level = (params[:standing] || 2).to_i.clamp(1, 3)
    @categories_with_items = categories_with_items(@standing_level)
  end

  # rubocop:disable Metrics/MethodLength
  def create
    authorize :bidding_round, :create?
    @bidding_round = BiddingRound.new(bidding_round_params)
    @bidding_round.project = @project

    if @bidding_round.save
      session[:selected_category_ids] = params[:category_ids]&.map(&:to_i)
      redirect_to select_artisans_project_bidding_round_path(@project)
    else
      @standing_level = @bidding_round.standing_level || 2
      @categories_with_items = categories_with_items(@standing_level)
      render :new, status: :unprocessable_entity
    end
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def select_artisans
    authorize @bidding_round, :select_artisans?
    @selected_category_ids = session[:selected_category_ids] || []
    @categories = WorkCategory.where(id: @selected_category_ids)

    @artisans_by_category = {}
    @categories.each do |category|
      @artisans_by_category[category.id] = Artisan
                                           .active
                                           .for_postcode(@project.location_zip)
                                           .for_category(category.id)
                                           .order(rating: :desc)
                                           .limit(10)
    end
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def update_artisans
    authorize @bidding_round, :update_artisans?

    selections = params[:artisan_selections] || {}

    selections.each do |category_id, artisan_ids|
      artisan_ids.first(3).each do |artisan_id|
        @bidding_round.bidding_requests.find_or_create_by!(
          work_category_id: category_id.to_i,
          artisan_id: artisan_id.to_i
        )
      end
    end

    @bidding_round.bidding_requests.pending_send.each do |request|
      SendBiddingRequestEmailJob.perform_later(request.id)
      request.update!(status: "sent", sent_at: Time.current)
    end

    @bidding_round.update!(status: "sent")
    BiddingDeadlineJob.set(wait_until: @bidding_round.deadline).perform_later(@bidding_round.id)
    session.delete(:selected_category_ids)

    redirect_to project_bidding_round_path(@project), notice: "Les demandes ont été envoyées aux artisans."
  end
  # rubocop:enable Metrics/MethodLength

  def send_requests
    authorize @bidding_round, :send_requests?

    @bidding_round.bidding_requests.pending_send.each do |request|
      SendBiddingRequestEmailJob.perform_later(request.id)
      request.update!(status: "sent", sent_at: Time.current)
    end

    @bidding_round.update!(status: "sent") unless @bidding_round.status == "sent"
    session.delete(:selected_category_ids)

    redirect_to project_bidding_round_path(@project), notice: "Les demandes ont été envoyées aux artisans."
  end

  def show
    authorize @bidding_round, :show?
    @requests_by_category = @bidding_round.bidding_requests
                                          .active
                                          .includes(:artisan, :work_category)
                                          .group_by(&:work_category)
  end

  def review_responses
    authorize @bidding_round, :review_responses?

    unless @bidding_round.ready_for_review?
      redirect_to project_bidding_round_path(@project), alert: "Les réponses ne sont pas encore toutes reçues."
      return
    end

    @recommendations = compute_recommendations
  end

  # rubocop:disable Metrics/MethodLength
  def confirm_selections
    authorize @bidding_round, :confirm_selections?

    selections = params[:selections] || {}

    ActiveRecord::Base.transaction do
      @bidding_round.final_selections.destroy_all

      selections.each do |category_id, request_id|
        request = @bidding_round.bidding_requests.find(request_id.to_i)
        ai_recommended = params[:ai_recommended_ids]&.include?(request_id.to_s)

        @bidding_round.final_selections.create!(
          work_category_id: category_id.to_i,
          bidding_request: request,
          ai_recommended: ai_recommended || false,
          confirmed_at: Time.current
        )
      end

      @bidding_round.update!(status: "completed")
    end

    redirect_to final_quote_project_bidding_round_path(@project), notice: "Vos sélections ont été confirmées."
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength
  def final_quote
    authorize @bidding_round, :final_quote?
    @final_selections = @bidding_round.final_selections.includes(:work_category, bidding_request: :artisan)
    @total_artisan_price = @final_selections.sum { |s| s.price_total.to_f }

    category_ids = @final_selections.map(&:work_category_id)
    standing = @bidding_round.standing_level
    @original_estimate = @project.rooms.joins(work_items: :work_category)
                                 .where(work_items: { standing_level: standing, work_category_id: category_ids })
                                 .sum("work_items.quantity * work_items.\"unit_price_exVAT\"")

    respond_to do |format|
      format.html
      format.pdf do
        pdf_data = FinalQuotePdfGenerator.new(@bidding_round).generate
        send_data pdf_data,
                  filename: "devis-#{@project.id}-#{Date.current}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def select_replacement
    authorize @bidding_round, :select_replacement?
    @bidding_request = @bidding_round.bidding_requests.find(params[:bidding_request_id])
    assigned_artisan_ids = @bidding_round.bidding_requests.active.pluck(:artisan_id)
    @available_artisans = Artisan.active
                                 .for_postcode(@project.location_zip)
                                 .for_category(@bidding_request.work_category_id)
                                 .where.not(id: assigned_artisan_ids)
                                 .order(rating: :desc)
                                 .limit(10)
  end

  # rubocop:disable Metrics/MethodLength
  def replace_artisan
    authorize @bidding_round, :replace_artisan?
    @old_request = @bidding_round.bidding_requests.find(params[:bidding_request_id])
    @new_artisan = Artisan.find(params[:new_artisan_id])

    @old_request.update!(status: "replaced")

    new_request = @bidding_round.bidding_requests.create!(
      work_category: @old_request.work_category,
      artisan: @new_artisan,
      status: "sent",
      sent_at: Time.current
    )

    @old_request.update!(replaced_by: new_request)
    SendBiddingRequestEmailJob.perform_later(new_request.id)

    redirect_to project_bidding_round_path(@project),
                notice: "#{@new_artisan.name} a été contacté(e) en remplacement."
  end
  # rubocop:enable Metrics/MethodLength

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_bidding_round
    @bidding_round = @project.bidding_round
    redirect_to new_project_bidding_round_path(@project) unless @bidding_round
  end

  def bidding_round_params
    params.require(:bidding_round).permit(:standing_level, :deadline)
  end

  def categories_with_items(standing_level)
    select_sql = "work_categories.*, COUNT(work_items.id) as items_count, " \
                 "SUM(work_items.quantity * work_items.\"unit_price_exVAT\") as subtotal_ht"
    WorkCategory
      .joins(work_items: { room: :project })
      .where(rooms: { project_id: @project.id })
      .where(work_items: { standing_level: standing_level })
      .select(select_sql)
      .group("work_categories.id")
      .order("work_categories.name")
  end

  # rubocop:disable Metrics/MethodLength
  def compute_recommendations
    recommendations = {}

    responded = @bidding_round.bidding_requests
                              .where(status: "responded")
                              .includes(:artisan, :work_category)

    responded.group_by(&:work_category_id).each do |category_id, requests|
      next if requests.empty?

      prices = requests.map { |r| r.price_total.to_f }
      min_price = prices.min
      max_price = prices.max

      scored = requests.map { |req| score_request(req, min_price, max_price) }
                       .sort_by { |s| -s[:score] }
      recommendations[category_id] = scored
    end

    recommendations
  end
  # rubocop:enable Metrics/MethodLength

  def score_request(req, min_price, max_price)
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
# rubocop:enable Metrics/ClassLength
