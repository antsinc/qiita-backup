class CreateGdriveSync < ActiveRecord::Migration
  def self.up
    create_table :gdrive_sync_items do |t|
      t.string :qiita_id, :null=>false
      t.timestamp :qiita_updated_at, :null=>false
      t.string :gdrive_id, :null=>false
      
      t.timestamps
    end

    add_index :gdrive_sync_items, [:qiita_id], :unique => true

  end
  def self.down
    drop_table :gdrive_sync_items
  end
end
