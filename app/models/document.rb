class Document < ActiveRecord::Base
  belongs_to :owner, inverse_of: :documents, class_name: 'User'

  scope :shared, -> { where(shared: true) }

  validate :validate_form_content

  def form_content=(new_content)
    if new_content.is_json?
      self.content = JSON.parse(new_content)
      @form_content = nil
    else
      @form_content = new_content
    end
  end

  def form_content
    @form_content || (content && content.to_json) || ""
  end

  protected

  def validate_form_content
    if form_content && !form_content.is_json?
      errors.add(:form_content, "must be valid json")
    end
  end

end
