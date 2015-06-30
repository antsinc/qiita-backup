class CreateQiitaItem < ActiveRecord::Migration
  def self.up
    create_table :qiita_items do |t|
      t.string :qiita_id, :null=>false
      t.timestamp :qiita_updated_at, :null=>false
      t.text :body
      
      t.timestamps
    end

    add_index :qiita_items, [:qiita_id], :unique => true
    add_index :qiita_items, [:qiita_updated_at]

  end
  def self.down
    drop_table :qiita_items
  end
end
