class ApplicationController < ActionController::Base
  before_filter :p3p_header

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  check_authorization :unless => :devise_controller?

  rescue_from CanCan::AccessDenied do |exception|
    raise ActiveRecord::RecordNotFound
  end

  private

  def after_sign_in_path_for(resource)
    session.delete('user_return_to') || root_path
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, access_params)
  end

  def access_params
    params.permit(:runKey)
  end

  def p3p_header
    response.headers['P3P'] = "CP='This site does not have a P3P policy.'"
  end
end
