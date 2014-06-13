class UsersController < ApplicationController
  before_filter :authenticate_user!

  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
    if @user != current_user
      redirect_to :root, flash: { error: 'Access denied.' }
      return
    end
  end

end
