class CreateDocuments < ActiveRecord::Migration
  def change
    create_table :documents do |t|
      t.text :title
      t.json :content
      t.boolean :shared, default: false
      t.integer :owner_id

      t.timestamps
    end

    add_index :documents, [:owner_id, :title]
    add_index :documents, :shared
  end
end
