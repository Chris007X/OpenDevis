module Artisans
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user!
    layout "artisan_dashboard"

    def new
      # Clear any stale Warden artisan session that could cause deserialization errors
      session.delete("warden.user.artisan.key")
    end

    def create
      artisan = Artisan.find_for_database_authentication(email: params.dig(:artisan, :email))

      if artisan&.valid_password?(params.dig(:artisan, :password))
        session[:artisan_id] = artisan.id
        redirect_to artisan_dashboard_root_path, notice: "Connecté avec succès."
      else
        flash.now[:alert] = "Email ou mot de passe incorrect."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:artisan_id)
      session.delete("warden.user.artisan.key")
      redirect_to new_artisan_session_path, notice: "Déconnecté avec succès."
    end

    private

    def skip_pundit?
      true
    end
  end
end
