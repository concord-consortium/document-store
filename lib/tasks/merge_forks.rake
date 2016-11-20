
def generate_view_url(doc)
  params = {recordid: doc[:id], accessKeys: {readOnly: doc[:read_access_key]}}
  "CODAP?launchFromLara=#{Base64.strict_encode64(params.to_json)}"
end

namespace :merge_forks do

  desc "creates new master documents for each dangling fork and updates documents to merge real forks"
  task merge_all: :environment do

    spreadsheet = {}

    num_parents = Document.select(:id).where(parent_id: nil).count
    Progress.start("Merging #{num_parents} possible master documents", num_parents) do
      Document.includes(:owner).where(parent_id: nil).find_in_batches(batch_size: 10) do |batch|
        batch.each do |parent_doc|
          parent_id = parent_doc[:id]

          if parent_doc.content && parent_doc.content.is_a?(Hash) && parent_doc.content.has_key?("contexts")
            contexts = []
            real_fork_ids = []
            changed_contexts = false

            parent_doc.content["contexts"].each do |obj|
              has_external_doc = false
              obj.each do |key,value|
                if key == "externalDocumentId"
                  has_external_doc = true
                  forked_doc = Document.find_by_id value.to_i
                  if forked_doc
                    real_fork_ids.push forked_doc[:id]
                    contexts.push forked_doc.content
                    changed_contexts = true
                    forked_doc.destroy
                  end
                end
              end
              if !has_external_doc
                contexts.push obj
              end
            end

            if changed_contexts
              new_content = parent_doc.content
              new_content["contexts"] = contexts
              parent_doc.contents.update_columns({content: new_content, updated_at: Time.current})

              parent_doc.create_access_keys()
              parent_doc.save!(:validate => false) # to get around title uniquness with nil run_key

              spreadsheet[parent_id] = {
                owner: parent_doc.owner ? parent_doc.owner.username : 'n/a',
                actions: ["merge real forks"],
                run_key: parent_doc[:run_key],
                real_fork_ids: real_fork_ids,
                master_url: generate_view_url(parent_doc),
                dangling_fork_urls: [],
                show_at_top: false
              }
            end
          end

          Progress.step 1
        end
      end
    end

    num_forks = Document.select(:parent_id).where.not(parent_id: nil).count
    Progress.start("Merging #{num_forks} dangling forked documents", num_forks) do
      Document.includes(:owner).where.not(parent_id: nil).find_in_batches(batch_size: 10) do |batch|
        batch.each do |forked_doc|
          parent_id = forked_doc[:parent_id]
          parent_doc = Document.find_by_id (forked_doc[:parent_id])

          if parent_doc && parent_doc.content && parent_doc.content.is_a?(Hash)
            new_content = parent_doc.content
            new_content["contexts"] = [forked_doc.content]
            forked_doc.contents.update_columns({content: new_content, updated_at: Time.current})

            forked_doc.create_access_keys()
            forked_doc.run_key = nil
            forked_doc.parent = nil
            forked_doc.save!(:validate => false) # to get around title uniquness with nil run_key

            if !spreadsheet.has_key?(parent_id)
              spreadsheet[parent_id] = {
                owner: parent_doc.owner ? parent_doc.owner.username : 'n/a',
                actions: [],
                run_key: parent_doc[:run_key],
                real_fork_ids: [],
                master_url: "",
                dangling_fork_urls: []
              }
            end
            if !spreadsheet[parent_id][:actions].include? "merge dangling forks"
              spreadsheet[parent_id][:actions].push "merge dangling forks"
            end
            spreadsheet[parent_id][:dangling_fork_urls].push generate_view_url(forked_doc)
            spreadsheet[parent_id][:show_at_top] = !!(spreadsheet[parent_id][:run_key] && spreadsheet[parent_id][:master_url])
          else
            # forked doc without parent or with a parent without a hash as content so destroy
            forked_doc.destroy
          end
          Progress.step 1
        end
      end
    end

    puts "id,owner,actions,real_fork_ids,run_key,master_url,dangling_fork_urls"
    spreadsheet.sort_by { |id, row| [row[:show_at_top] ? 0 : 1, id] }.each do |id, row|
      puts "#{id},#{row[:owner]},#{row[:actions].join(' & ')},#{row[:real_fork_ids].join(' & ')},#{row[:run_key] || ''},#{row[:master_url] || ''},#{row[:dangling_fork_urls].join(',') || ''}"
    end
  end
end
