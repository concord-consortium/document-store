class AddOriginalContentToDocuments < ActiveRecord::Migration
  def change
    add_column :documents, :original_content, :json
  end
end
