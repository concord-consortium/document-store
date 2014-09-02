class AddRunKeyToDocument < ActiveRecord::Migration
  def change
    add_column :documents, :run_key, :string
    add_index :documents, [:owner_id, :title, :run_key]
  end
end
