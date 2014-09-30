class Document < ActiveRecord::Base
  belongs_to :owner, inverse_of: :documents, class_name: 'User'

  scope :shared, -> { where(shared: true) }

  validates :title, uniqueness: {scope: [:owner, :run_key]}
  validate :validate_form_content

  after_save :sync_attributes

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
    content_dirty = false
    c = self.content
    content_dirty ||= _set_attribute(c, "name", title)
    content_dirty ||= _set_attribute(c, "_permissions", (shared ? 1 : 0))

    original_content_dirty = false
    oc = self.original_content
    original_content_dirty ||= _set_attribute(oc, "name", title)
    original_content_dirty ||= _set_attribute(oc, "_permissions", (shared ? 1 : 0))

    atts_to_update = {}
    atts_to_update[:content] = c if content_dirty
    atts_to_update[:original_content] = oc if original_content_dirty
    update_columns(atts_to_update) if atts_to_update.size > 0

    return true
  end

  def _has_attribute?(c, key)
    has_a = !c.nil? && c.is_a?(Hash) && c.has_key?(key)
    return has_a
  end

  def _set_attribute(c, key, value)
    if _has_attribute?(c, key) && c[key] != value
      c[key] = value
      return true
    else
      return false
    end
  end

end
