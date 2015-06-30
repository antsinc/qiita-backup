class CreateEvernoteSync < ActiveRecord::Migration
  def self.up
    create_table :evernote_sync_items do |t|
      t.string :qiita_id, :null=>false
      t.timestamp :qiita_updated_at, :null=>false
      t.string :evernote_id, :null=>false
      
      t.timestamps
    end

    add_index :evernote_sync_items, [:qiita_id], :unique => true

  end
  def self.down
    drop_table :evernote_sync_items
  end
end
