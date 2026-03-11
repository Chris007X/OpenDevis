module ArtisanDashboard
  class BaseController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :authenticate_artisan!
    layout "artisan_dashboard"

    private

    def current_artisan
      @current_artisan ||= Artisan.find_by(id: session[:artisan_id])
    end
    helper_method :current_artisan

    def authenticate_artisan!
      redirect_to new_artisan_session_path, alert: "Connectez-vous pour accéder à votre tableau de bord." unless current_artisan
    end

    def skip_pundit?
      true
    end
  end
end
