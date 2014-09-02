class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  check_authorization :unless => :devise_controller?

  rescue_from CanCan::AccessDenied do |exception|
    raise ActiveRecord::RecordNotFound
  end

  private

  def after_sign_in_path_for(resource)
    session['user_return_to'] || root_path
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, access_params)
  end

  def access_params
    params.permit(:runKey)
  end
end
