class Ability
  include CanCan::Ability

  def initialize(user, extra={})
    # Stuff everyone can do
    can [:read, :open], Document do |doc|
      doc.shared
    end
    can [:read, :open], :url_document
    can [:info], :nil_user
    can [:not_found, :not_authorized], :nil_document

    if user
      # Stuff logged in people can do

      # Document
      can [:index, :list, :create, :new, :all], Document
      can [:read, :show, :edit, :update, :destroy, :save, :open], Document do |doc|
          doc.owner == user
      end

      # User
      can [:read, :update, :info, :authenticate], User do |u|
        u == user
      end
    else
      # anonymous gets read/write access to documents if they know the documents run_key
      if extra[:runKey]
        can [:index, :list, :all], Document
        can [:read, :show, :edit, :update, :destroy, :save, :open], Document do |doc|
            doc.owner.nil? && doc.run_key == extra[:runKey]
        end
      end
      # anonymous can't do anything else
    end
  end
end
