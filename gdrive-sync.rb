require 'bundler/setup'

require "google/api_client"
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/file_storage'
require "google_drive"

require 'active_record'
require 'yaml'
require 'sqlite3'
require 'string/scrub'
require 'qiita-markdown'

require './model'


CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"

class GdriveSync
  def initialize(config)
    @client = Google::APIClient.new(:application_name => 'qiita-gdrive-sync',
                                    :application_version => '1.0')

    file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
    if file_storage.authorization.nil?

      flow = Google::APIClient::InstalledAppFlow.new(
          :client_id => config["gdrive"]["client_id"],
          :client_secret => config["gdrive"]["client_secret"],
          :scope => [
            "https://www.googleapis.com/auth/drive",
            "https://docs.google.com/feeds/",
            "https://docs.googleusercontent.com/",
            "https://spreadsheets.google.com/feeds/"
        ]
      )
      @client.authorization = flow.authorize(file_storage)
    else
      @client.authorization = file_storage.authorization
    end
    
    @session = GoogleDrive.login_with_oauth(@client.authorization.access_token)
    @folder = @session.collection_by_title(config['gdrive']['folder_name'])
    if not @folder then
      @folder = @session.root_collection.create_subcollection(config['gdrive']['folder_name'])
    end
  end


  def update_content(item)
    body = JSON.parse(item.body)

    # 書き出すHTMLを準備
    text = body["body"].scrub("?")
    processor = Qiita::Markdown::Processor.new
    output = Qiita::Markdown::Filters::Redcarpet.renderer.render(text)
    html = output.scrub("?")

    gdrive_item = GdriveSyncItem.find_by qiita_id: item.qiita_id
    if gdrive_item then
      file = @session.file_by_id(gdrive_item.gdrive_id)
      file.update_from_string(html)
    else
      # 新規ファイル
      file = @session.upload_from_string(html, body["title"], {:content_type=>"text/html"})
      @folder.add(file)
    end

    gdrive_item = GdriveSyncItem.find_or_initialize_by(qiita_id: item.qiita_id)

    gdrive_item.qiita_updated_at = item.updated_at
    gdrive_item.gdrive_id = file.id
    gdrive_item.save()
  end

end


if $0 == __FILE__ then
  config = YAML.load_file('config.yml')
  ActiveRecord::Base.establish_connection(config["db"][ENV['ENV']])

  item = QiitaItem.find_by qiita_id: ARGV[0]

  sync = GdriveSync.new(config)
  sync.update_content(item)
end
