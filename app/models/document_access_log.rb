class DocumentAccessLog < ActiveRecord::Base
  self.table_name = "document_access_log"

  before_save :generate_timestamp

  def self.log(document_id, api_version, action, access_params)
    entry = DocumentAccessLog.new
    entry.document_id = document_id
    entry.action = action
    entry.access_params = access_params
    entry.api_version = api_version
    entry.save
  end

  def generate_timestamp
    self.accessed_at = DateTime.now
  end
end
