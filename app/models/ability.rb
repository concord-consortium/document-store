class Ability
  include CanCan::Ability

  def initialize(user)
    if user
        can [:read, :open], Document.shared
        can [:index, :list, :create, :new, :all], Document
        can [:show, :edit, :update, :destroy, :save, :open], Document do |doc|
            doc.owner == user
        end

    end
  end
end
