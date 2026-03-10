class RoomsController < ApplicationController
  before_action :set_room, only: [:show, :edit, :update, :destroy]

  def index
    @project = policy_scope(Project).find(params[:project_id])
    @rooms = policy_scope(Room).where(project: @project).includes(:work_items)
  end

  def show
    @work_items = @room.work_items.includes(:work_category, :material)
  end

  def new
    @project = policy_scope(Project).find(params[:project_id])
    @room = Room.new(project: @project)
    authorize @room
  end

  def create
    @project = policy_scope(Project).find(params[:project_id])
    @room = Room.new(room_params)
    @room.project = @project
    authorize @room
    if @room.save
      redirect_to @project, notice: "Pièce ajoutée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      redirect_to @room.project, notice: "Pièce mise à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = @room.project
    @room.destroy
    redirect_to @project, notice: "Pièce supprimée."
  end

  private

  def set_room
    @room = Room.find(params[:id])
    authorize @room
  end

  def room_params
    params.require(:room).permit(:name, :surface_sqm, :perimeter_lm, :wall_height_m)
  end
end
