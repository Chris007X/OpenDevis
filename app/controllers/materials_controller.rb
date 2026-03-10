class MaterialsController < ApplicationController
  def index
    @materials = policy_scope(Material).includes(:work_category).order(:brand)
  end

  def show
    @material = Material.find(params[:id])
    authorize @material
  end
end
