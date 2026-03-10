class WorkCategoriesController < ApplicationController
  def index
    @work_categories = policy_scope(WorkCategory).includes(:materials).order(:name)
  end

  def show
    @work_category = WorkCategory.find(params[:id])
    authorize @work_category
    @materials = @work_category.materials.order(:brand)
  end
end
