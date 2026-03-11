class WorkItemsController < ApplicationController
  before_action :set_work_item, only: %i[edit update destroy]

  def new
    @room = Room.find(params[:room_id])
    @work_item = WorkItem.new(room: @room)
    authorize @work_item
    load_form_data
  end

  def create
    @room = Room.find(params[:room_id])
    @work_item = WorkItem.new(work_item_params)
    @work_item.room = @room
    authorize @work_item
    if @work_item.save
      redirect_to @room, notice: "Poste de travaux ajouté."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @work_item.update(work_item_params)
      redirect_to @work_item.room, notice: "Poste de travaux mis à jour."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room = @work_item.room
    @work_item.destroy
    redirect_to @room, notice: "Poste de travaux supprimé."
  end

  private

  def set_work_item
    @work_item = WorkItem.find(params[:id])
    authorize @work_item
  end

  def load_form_data
    @work_categories = WorkCategory.order(:name)
    @materials = Material.includes(:work_category).order(:brand)
  end

  def work_item_params
    params.require(:work_item).permit(:label, :quantity, :unit, :unit_price_exVAT, :standing_level, :vat_rate,
                                      :work_category_id, :material_id)
  end
end
