class ApplicationController < ActionController::Base
  before_action :authenticate_user!, unless: :artisan_route?
  include Pundit::Authorization # <-- Cette ligne doit être présente

  # Optionnel au Wagon : lever une erreur si on oublie d'autoriser une action en dev
  after_action :verify_authorized, unless: -> { skip_pundit? || action_name == "index" }
  after_action :verify_policy_scoped, unless: :skip_pundit?, if: -> { action_name == "index" }

  private

  def after_sign_in_path_for(resource)
    resource.is_a?(User) ? projects_path : super
  end

  def skip_pundit?
    devise_controller? || artisan_route? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end

  def artisan_route?
    params[:controller].to_s.start_with?("artisan_dashboard", "artisans/")
  end
end
