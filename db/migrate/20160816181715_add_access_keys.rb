class AddAccessKeys < ActiveRecord::Migration
  def change
    add_column :documents, :read_access_key, :string, default: nil
    add_column :documents, :read_write_access_key, :string, default: nil

    add_index :documents, :read_access_key
    add_index :documents, :read_write_access_key

    # copy the CFM generated run_keys to the read_write_access_key
    reversible do |dir|
      dir.up do
        Document.select(:run_key).where(shared: true).where("run_key similar to '[0-9a-f]+'").each do |document|
          document.update_column(:read_write_access_key, document.run_key)
        end
      end
    end
  end
end
