class UsersController < ApplicationController
  before_filter :store_return_url, :only => [:authenticate]
  before_filter :authenticate_user!, :except => [:info]
  skip_before_filter :verify_authenticity_token, :only => [:info]

  def index
    authorize! :list, User
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
    authorize! :read, @user
  end

  def authenticate
    authorize! :authenticate, current_user
    redirect_to session[:auth_return_url] || root_path
  end

  # Generates CODAP-style user info, suitable for passing into its authentication routines
  def info
    if current_user
      @user = current_user
      authorize! :info, @user
      render json: {
        valid: true,
        sessionToken: "abc123", # unnecessary, but here to avoid breaking anything
        enableLogging: false,   # disabled, for now
        privileges: 0,          # 1 means developer. For now, nobody is a developer.
        useCookie: false,       # ???
        enableSave: true,       # Saving is good.
        username: @user.username,
        name: @user.name
      }
    else
      authorize! :info, :nil_user
      render json: {valid: false}, status: 401
    end
  end

  protected

  def store_return_url
    unless current_user
      session[:auth_return_url] = request.env["HTTP_REFERER"] || nil
    end
  end
end
