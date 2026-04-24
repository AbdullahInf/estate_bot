class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_broker, :broker_signed_in?

  private

  def current_broker
    @current_broker ||= Broker.find_by(id: session[:broker_id])
  end

  def broker_signed_in?
    current_broker.present?
  end

  def require_broker
    redirect_to signin_path, alert: "Please sign in to continue." unless broker_signed_in?
  end
end
