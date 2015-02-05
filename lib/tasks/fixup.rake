namespace :fixup do
  desc "Resets the is_codap_main_document flag on each Document"
  task reset_is_codap_main_document: :environment do
    Progress.start("Resetting #{Document.count} Documents", Document.count) do
      Document.find_each(batch_size: 100) do |doc|
        is_main_doc = doc._is_codap_main_doc
        is_main_doc_dirty = doc.is_codap_main_document != is_main_doc
        doc.update_columns(is_codap_main_document: is_main_doc) if is_main_doc_dirty
        Progress.step 1
      end
    end
  end
end
