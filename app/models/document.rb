class Document < ActiveRecord::Base
  belongs_to :owner, inverse_of: :documents, class_name: 'User'
  has_one :contents, class_name: 'DocumentContent', dependent: :destroy, autosave: true

  has_many :children, class_name: 'Document', foreign_key: 'parent_id', dependent: :destroy
  belongs_to :parent, class_name: 'Document' #, dependent: :destroy -- handled in after_destroy :destroy_parent

  delegate :content, :content=, :original_content, :original_content=, to: :contents

  scope :shared, -> { where(shared: true) }

  validates :title, uniqueness: {scope: [:owner, :run_key]}, if: :has_owner?
  validate :validate_form_content

  after_save :sync_attributes
  #before_destroy :store_parent
  #after_destroy :destroy_parent # workaround for https://github.com/rails/rails/issues/13609

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

  def create_access_keys
    # generate two unique new access keys - we can't use a unique index constraint because the keys will be null for older documents
    # giving the length of the random strings this will probably never loop
    read_access_key = nil
    read_write_access_key = nil
    loop do
      read_access_key = SecureRandom.hex(20)
      read_write_access_key = SecureRandom.hex(40)
      break if !Document.find_by(read_access_key: read_access_key) && !Document.find_by(read_write_access_key: read_write_access_key)
    end
    self.read_access_key = read_access_key if self.read_access_key.nil?
    self.read_write_access_key = read_write_access_key if self.read_write_access_key.nil?
  end

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

  def store_parent
    @saved_parent = parent
    self.parent = nil
  end

  def destroy_parent
    return unless @saved_parent
    @saved_parent.destroy unless @saved_parent.destroyed?
  end

  def has_owner?
    self.owner != nil
  end

end
