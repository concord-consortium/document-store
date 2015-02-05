class AddIsCodapMainDocumentToDocuments < ActiveRecord::Migration
  def change
    add_column :documents, :is_codap_main_document, :boolean, default: true
  end
end
