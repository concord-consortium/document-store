class UsersController < ApplicationController
  before_filter :authenticate_user!

  def index
    authorize! :list, User
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
    authorize! :read, @user
  end

end
