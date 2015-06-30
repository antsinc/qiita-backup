require 'bundler/setup'

require 'active_record'
require 'yaml'
require 'sqlite3'
require 'string/scrub'
require 'qiita-markdown'
require 'rexml/document'
require 'rexml/formatters/transitive'

require 'oauth'
require 'oauth/consumer'
require "evernote_oauth"

require './model'
require './qiita-image-download'

#OAUTH_CONSUMER_KEY = "kojitaro"
#OAUTH_CONSUMER_SECRET = "decf5f457b1e0761"
#SANDBOX = true
#DEVELOPER_TOKEN = "S=s1:U=8d1c6:E=154f6446556:C=14d9e9338b0:P=1cd:A=en-devtoken:V=2:H=0556849ccce7866d487abff6826cdfea"


class EvernoteSync
  def initialize(config)
    @client = EvernoteOAuth::Client.new(token: config['evernote']['developer_token'],
                                          consumer_key:config['evernote']['consumer_key'],
                                          consumer_secret:config['evernote']['consumer_secret'],
                                          sandbox: config['evernote']['sandbox'])
		@imageDownload = QiitaImageDownload.new(config)

		self.prepare_notebook(config['evernote']['notebook'])
  end

	def prepare_notebook(notebook_name)
		notebooks = @client.note_store.listNotebooks()
		notebooks.each do |notebook|
			if notebook.name == notebook_name then
				@parent_notebook = notebook
				return
			end
		end

		# Notebookを作る
		notebook = Evernote::EDAM::Type::Notebook.new
		notebook.name = notebook_name
		@client.note_store.createNotebook(notebook)

		@parent_notebook = notebook
	end

  def update_content(item)
    body = JSON.parse(item.body)

    ## Create note object
		note = nil
    begin
			evernote_item = EvernoteSyncItem.find_by qiita_id: item.qiita_id
			if evernote_item then
				note = @client.note_store.getNote(evernote_item.evernote_id,
																				 false,false,false,false)
				self.prepare_note(note, body)
				@client.note_store.updateNote(note)
			end

			if not note then	
				note = Evernote::EDAM::Type::Note.new
				self.prepare_note(note, body)
				if @parent_notebook && @parent_notebook.guid
					note.notebookGuid = @parent_notebook.guid
				end
				note = @client.note_store.createNote(note)
				p note
			end

    rescue Evernote::EDAM::Error::EDAMUserException => ex
      parameter = ex.parameter
      errorCode = ex.errorCode
      errorText = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]

      puts "Authentication failed (parameter: #{parameter} errorCode: #{errorText})"
    rescue Evernote::EDAM::Error::EDAMNotFoundException => ednfe
      puts "EDAMNotFoundException: Invalid parent notebook GUID"
    end

    puts note.guid

    evernote_item = EvernoteSyncItem.find_or_initialize_by(qiita_id: item.qiita_id)
    evernote_item.qiita_updated_at = item.updated_at
    evernote_item.evernote_id = note.guid
    evernote_item.save()
  end

	# QiitaデータをNoteにセット
	def prepare_note(note, body)
		note.tagNames = body['tags'].map{|tag|tag['name']}
		#note.created = body['created']
		#note.updated = body['updated']

		attributes = Evernote::EDAM::Type::NoteAttributes.new
		attributes.sourceURL = body['url']
		attributes.sourceApplication = "qiita-backup"
		attributes.subjectDate = body['created']
		attributes.author = body['user']['id']
		note.attributes = attributes

    # 書き出すHTMLを準備
    text = body["body"].scrub("?")
    processor = Qiita::Markdown::Processor.new
    output = Qiita::Markdown::Filters::Redcarpet.renderer.render(text)
    html = output.scrub("?")

    doc = Nokogiri::HTML::Document.parse html



    # imgタグを差し替える
    doc.css('img').each do |image|
			begin
				imgsrc = image.attribute("src").value
				image_path = @imageDownload.find_localpath(imgsrc)
				extension = File.extname(image_path)
				content_type = MIME::Types.type_for(extension).first.content_type

				resource_hash = note.add_resource(image_path, File.binread(image_path), content_type)

				image.parent.add_child("<en-media type =\"%s\" hash=\"%s\">" % [content_type, resource_hash]);
				
			rescue => e
				p e
			end
    end

    # XHTMLとして書き出す
    html = doc.root.children[0].inner_html(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML)

    n_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    n_body += "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">"
    n_body += "<en-note>#{html}</en-note>"

    note.title = body["title"]
    note.content = n_body

	end


end


if $0 == __FILE__ then
  config = YAML.load_file('config.yml')
  ActiveRecord::Base.establish_connection(config["db"][ENV['ENV']])

  item = QiitaItem.find_by qiita_id: ARGV[0]

  sync = EvernoteSync.new(config)
  sync.update_content(item)
end
