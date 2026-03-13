class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update destroy archive]

  def index
    @projects = policy_scope(Project).order(updated_at: :desc)
  end

  def show
    @standing  = (params[:standing]&.to_i || 2).clamp(1, 3)
    @rooms     = @project.rooms.includes(:work_items)
    @documents = @project.documents.order(uploaded_at: :desc)

    filtered = @project.work_items.where(standing_level: @standing).includes(:work_category)

    @total_ht  = filtered.sum { |i| (i.quantity || 0) * (i.unit_price_exVAT || 0) }
    @total_ttc = filtered.sum do |i|
      exvat = (i.quantity || 0) * (i.unit_price_exVAT || 0)
      exvat * (1 + ((i.vat_rate || 0) / 100.0))
    end
    @categories_data = filtered
                       .group_by(&:work_category)
                       .map do |cat, items|
                         subtotal = items.sum { |i| (i.quantity || 0) * (i.unit_price_exVAT || 0) }
                         { category: cat, count: items.count, total: subtotal }
                       end
                       .sort_by { |d| -d[:total] }
  end

  def new
    redirect_to wizard_step1_path
  end

  def create
    @project = Project.new(project_params)
    @project.user = current_user
    authorize @project
    if @project.save
      redirect_to @project, notice: "Projet créé."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Projet mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Projet supprimé."
  end

  def archive
    @project.archived!
    redirect_to @project, notice: "Projet archivé."
  end

  private

  def set_project
    @project = Project.find(params[:id])
    authorize @project
  end

  def project_params
    params.require(:project).permit(:status, :location_zip, :room_count, :total_surface_sqm, :energy_rating,
                                    :property_url)
  end
end
