class Document < ActiveRecord::Base
  belongs_to :owner, inverse_of: :documents, class_name: 'User'
  has_one :contents, class_name: 'DocumentContent', dependent: :destroy, autosave: true

  has_many :children, class_name: 'Document', foreign_key: 'parent_id', dependent: :destroy
  belongs_to :parent, class_name: 'Document', dependent: :destroy

  delegate :content, :content=, :original_content, :original_content=, to: :contents

  scope :shared, -> { where(shared: true) }

  validates :title, uniqueness: {scope: [:owner, :run_key]}
  validate :validate_form_content

  after_save :sync_attributes

  def form_content=(new_content)
    if new_content.is_json?
      self.content = new_content.parsed_json
      @form_content = nil
    else
      @form_content = new_content
    end
  end

  def form_content
    @form_content || (content && content.to_json) || ""
  end

  def contents_with_check
    self.contents_without_check || (self.contents = DocumentContent.new)
  end
  alias_method_chain :contents, :check

  protected

  def validate_form_content
    if form_content && !form_content.is_json?
      errors.add(:form_content, "must be valid json")
    end
  end

  def sync_attributes
    is_main_doc = contents.is_codap_main_document
    is_main_doc_dirty = is_codap_main_document != is_main_doc

    atts_to_update = {}
    atts_to_update[:is_codap_main_document] = is_main_doc if is_main_doc_dirty
    update_columns(atts_to_update) if atts_to_update.size > 0

    return true
  end

end
