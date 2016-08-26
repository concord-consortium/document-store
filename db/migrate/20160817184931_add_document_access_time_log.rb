class AddDocumentAccessTimeLog < ActiveRecord::Migration
  def change
    create_table :document_access_log do |t|
      t.integer :document_id
      t.string :api_version
      t.string :action
      t.string :access_params
      t.timestamp :accessed_at
    end
  end
end
