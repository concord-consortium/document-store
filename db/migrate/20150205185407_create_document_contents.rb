class CreateDocumentContents < ActiveRecord::Migration
  class Document < ActiveRecord::Base
    has_one :contents, class_name: 'DocumentContent'
  end

  class DocumentContent < ActiveRecord::Base
    belongs_to :document, class_name: 'Document'
  end

  def up
    create_table :document_contents do |t|
      t.integer :document_id
      t.json :content
      t.json :original_content

      t.timestamps
    end

    add_index :document_contents, :document_id

    Progress.start("Migrating #{Document.count} Documents' contents", Document.count) do
      Document.find_each(batch_size: 100) do |doc|
        dc = DocumentContent.find_or_create_by(document_id: doc.id)
        dc.update_columns(content: doc.content, original_content: doc.original_content, created_at: doc.created_at, updated_at: doc.updated_at)
        Progress.step 1
      end
    end

    remove_column :documents, :content
    remove_column :documents, :original_content
  end
  def down
    add_column :documents, :content, :json
    add_column :documents, :original_content, :json

    Progress.start("Migrating #{Document.count} Documents' contents", DocumentContent.count) do
      DocumentContent.find_each(batch_size: 100) do |dc|
        doc = dc.document
        doc.content = dc.content
        doc.original_content = dc.original_content
        doc.update_columns(content: dc.content, original_content: dc.original_content)
        Progress.step 1
      end
    end

    drop_table :document_contents
  end
end
