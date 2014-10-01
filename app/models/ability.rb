class Ability
  include CanCan::Ability

  def initialize(user, extra={})
    # Stuff everyone can do
    can [:read, :open, :show], Document do |doc|
      doc.shared
    end
    can [:read, :open], :url_document
    can [:info], :nil_user
    can [:not_found, :not_authorized, :duplicate_error], :nil_document
    can [:save], :document do
      !user.nil? || !extra[:runKey].blank?
    end

    if user
      # Stuff logged in people can do

      # Document
      can [:index, :list, :create, :new, :all], Document

      # read a doc
      can [:read, :show, :open], Document do |doc|
          doc.owner == user || (!doc.run_key.blank? && doc.run_key == extra[:runKey])
      end

      # write a doc
      can [:edit, :update, :destroy, :save, :open_original], Document do |doc|
          doc.owner == user || (doc.owner.nil? && !doc.run_key.blank? && doc.run_key == extra[:runKey])
      end

      # User
      can [:read, :update, :info, :authenticate, :report], User do |u|
        u == user
      end
    else
      # anonymous gets read/write access to documents if they know the documents run_key
      if extra[:runKey]
        can [:index, :list, :all], Document
        can [:read, :show, :edit, :update, :destroy, :save, :open, :open_original], Document do |doc|
            doc.owner.nil? && !doc.run_key.blank? && doc.run_key == extra[:runKey]
        end
      end
      # anonymous can't do anything else
    end
  end
end
