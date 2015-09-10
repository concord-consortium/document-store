class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  Concord::AuthPortal.all.each_pair do |key, portal|
    # dynamically create the controller action for this strategy see concord/auth_portal.rb
    class_eval portal.controller_action
  end

  # NOTE: it can be handy to setup debug points for these methods action_missing(provider) and passthru(provider)

  def failure
    if request.referer && request.referer.index(request.host+launch_path)
      loc = Addressable::URI.parse(request.referer)
      new_query = loc.query_values || {}
      new_query["auto_auth_failed"] = true
      loc.query_values = new_query
      redirect_to loc.to_s
    else
      redirect_to new_user_session_path
    end
  end

end
