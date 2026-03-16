class ApplicationController < ActionController::Base
  include Trackable
  before_action :authenticate_user!, unless: :artisan_route?
  include Pundit::Authorization # <-- Cette ligne doit être présente

  # Optionnel au Wagon : lever une erreur si on oublie d'autoriser une action en dev
  after_action :verify_authorized, unless: -> { skip_pundit? || action_name == "index" }
  after_action :verify_policy_scoped, unless: :skip_pundit?, if: -> { action_name == "index" }

  rescue_from StandardError, with: :track_and_reraise

  private

  def track_and_reraise(exception)
    # Skip common non-bug exceptions (auth redirects, missing records that render 404, etc.)
    ignorable = [
      ActionController::RoutingError,
      ActionController::UnknownFormat,
      Pundit::NotAuthorizedError,
      ActiveRecord::RecordNotFound
    ]
    unless ignorable.any? { |klass| exception.is_a?(klass) }
      AnalyticsTracker.track(
        event_type:  "server_error",
        session_id:  analytics_session_id,
        user_id:     current_analytics_user_id,
        page_path:   request.path,
        user_agent:  request.user_agent,
        ip_address:  anonymized_ip,
        properties:  {
          exception_class:   exception.class.name,
          exception_message: exception.message.truncate(300),
          controller:        "#{params[:controller]}##{params[:action]}"
        }
      )
    end
    raise exception
  end

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
