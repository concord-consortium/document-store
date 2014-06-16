class Ability
  include CanCan::Ability

  def initialize(user)
    if user
        # Document
        can [:read, :open], Document.shared
        can [:index, :list, :create, :new, :all], Document
        can [:show, :edit, :update, :destroy, :save, :open], Document do |doc|
            doc.owner == user
        end

        # User
        can [:read, :update], User do |u|
          u == user
        end
    else
      # anonymous can't do anything
    end
  end
end
