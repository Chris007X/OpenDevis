class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  include Pundit::Authorization # <-- Cette ligne doit être présente

  # Optionnel au Wagon : lever une erreur si on oublie d'autoriser une action en dev
  after_action :verify_authorized, unless: -> { skip_pundit? || action_name == "index" }
  after_action :verify_policy_scoped, unless: :skip_pundit?, if: -> { action_name == "index" }

  private

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end
end
