class AddAccessKeys < ActiveRecord::Migration
  def change
    add_column :documents, :read_access_key, :string, default: nil
    add_column :documents, :read_write_access_key, :string, default: nil

    add_index :documents, :read_access_key
    add_index :documents, :read_write_access_key

    # copy the CFM generated run_keys to the read_write_access_key
    Document.select(:run_key).where(shared: true).where("run_key similar to '[0-9a-f]+'").each do |document|
      document.read_write_access_key = document.run_key
      document.save(:validate => false) # some existing documents won't validate because their owner and title are both null
    end
  end
end
