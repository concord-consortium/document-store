class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  Concord::AuthPortal.all.each_pair do |key, portal|
    # dynamically create the controller action for this strategy see concord/auth_portal.rb
    class_eval portal.controller_action
  end

  # NOTE: it can be handy to setup debug points for these methods action_missing(provider) and passthru(provider)

end
