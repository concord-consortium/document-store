class DocumentContent < ActiveRecord::Base
  belongs_to :document, inverse_of: :contents, class_name: 'Document'

  after_save :sync_attributes

  delegate :title, :shared, to: :document

  # A document is a codap main document if it has all 3 keys: appName, appVersion, appBuildNum.
  # Don't worry about their value, since that can change.
  def is_codap_main_document
    return content.is_a?(Hash) && (["appName", "appVersion", "appBuildNum"] - content.keys).empty?
  end

  protected

  def sync_attributes
    content_dirty = false
    c = self.content
    content_dirty ||= _set_attribute(c, "_permissions", (shared ? 1 : 0))

    original_content_dirty = false
    oc = self.original_content
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
