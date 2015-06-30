require 'bundler/setup'

require "yaml"
require 'json'
require 'active_record'
require 'sqlite3'
require 'qiita'

require './model'
require './qiita-image-download'
require './gdrive-sync.rb'
require './evernote-sync.rb'

PER_PAGE = 100


class QiitaUpdateChecker
  def initialize(client, config)
    @client = client
    @last_updated_at = QiitaItem.last_updated_at

    if config.has_key?('image') then
      @image_download = QiitaImageDownload.new(config)
    else
      @image_download = nil
    end

    if config.has_key?('gdrive') then
      @gdrive_sync = GdriveSync.new(config)
    else
      @gdrive_sync = nil
    end

    if config.has_key?('evernote') then
      @evernote_sync = EvernoteSync.new(config)
    else
      @evernote_sync = nil
    end

  end

  def check(user)
    page = 1
    while true do
      if user then
        r = @client.list_user_items(user, page:page,per_page:PER_PAGE)
      else
        r = @client.list_items(page:page,per_page:PER_PAGE)
      end

      if r.body.length == 0 then
        return
      end

      for item in r.body do
				if item.kind_of? Array then
					# Not Found
					return
				end

        updated_at = DateTime.parse(item["updated_at"])
        if @last_updated_at and @last_updated_at.to_i >= updated_at.to_i then
          next
          #return
        end

        qiita_item = QiitaItem.find_or_initialize_by(qiita_id: item["id"])
        qiita_item.qiita_updated_at = updated_at
        qiita_item.body = JSON.unparse(item)
        qiita_item.save()

        #print item["id"]
        #print "\n"

        if @image_download then
          @image_download.update_content(qiita_item)
        end
        if @gdrive_sync then
          @gdrive_sync.update_content(qiita_item)
        end
        if @evernote_sync then
          @evernote_sync.update_content(qiita_item)
        end
      end

      page+=1
    end
  end
end


if $0 == __FILE__ then
  config = YAML.load_file('config.yml')
  client = Qiita::Client.new(access_token: config["access_token"], team:config["team"])
  ActiveRecord::Base.establish_connection(config["db"][ENV['ENV']])

  ck = QiitaUpdateChecker.new(client, config)
  ck.check(config['user'])
end





