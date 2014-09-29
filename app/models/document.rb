class Document < ActiveRecord::Base
  belongs_to :owner, inverse_of: :documents, class_name: 'User'

  scope :shared, -> { where(shared: true) }

  validates :title, uniqueness: {scope: [:owner, :run_key]}
  validate :validate_form_content

  before_save :sync_attributes

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

  def sync_attributes
    content["name"] = title if _has_attribute?(content, "name")
    original_content["name"] = title if _has_attribute?(original_content, "name")

    content["_permissions"] = (shared ? 1 : 0) if _has_attribute?(content, "_permissions")
    original_content["_permissions"] = (shared ? 1 : 0) if _has_attribute?(original_content, "_permissions")
  end

  def _has_attribute?(c, key)
    return c && c.is_a?(Hash) && c.has_key?(key)
  end

end
