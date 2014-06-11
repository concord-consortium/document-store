class Document < ActiveRecord::Base
  belongs_to :owner, inverse_of: :documents, class_name: 'User'

  scope :shared, -> { where(shared: true) }
end
