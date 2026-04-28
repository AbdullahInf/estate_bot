class AuthController < ApplicationController
  def new
    redirect_to dashboard_path if broker_signed_in?
  end

  def destroy
    session.delete(:broker_id)
    redirect_to signin_path, notice: "You have been signed out."
  end
end
