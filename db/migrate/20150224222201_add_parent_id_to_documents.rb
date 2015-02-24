class AddParentIdToDocuments < ActiveRecord::Migration
  def change
    add_column :documents, :parent_id, :integer, default: nil

    add_index :documents, :parent_id
  end
end
