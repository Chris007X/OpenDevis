module ArtisanDashboard
  class ProfilesController < BaseController
    def show
      @artisan = current_artisan
    end

    def edit
      @artisan = current_artisan
      @work_categories = WorkCategory.order(:name)
    end

    def update
      @artisan = current_artisan
      @work_categories = WorkCategory.order(:name)
      if @artisan.update(profile_params)
        redirect_to artisan_dashboard_profile_path, notice: "Profil mis à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:artisan).permit(:name, :company_name, :phone, :postcode, :portfolio_url, :certifications,
                                      work_category_ids: [])
    end
  end
end
