require 'bundler/setup'

require "yaml"
require "json"
require 'active_record'
require 'sqlite3'
require 'nokogiri'
require 'digest/sha1'
require 'open-uri'
require 'mime/types'
require 'string/scrub'
require "fileutils"

require 'qiita-markdown'

require './model'


class QiitaImageDownload
  def initialize(config)
    @data_path = config['image']['image_path']
    FileUtils.mkdir_p(@data_path)
  end

  def update_content(item)
    body = JSON.parse(item.body)

    # replace invalid byte
    text = body["body"].scrub("?")

    #processor = Qiita::Markdown::Processor.new
    output = Qiita::Markdown::Filters::Redcarpet.renderer.render(text)
    
    doc = Nokogiri::HTML.parse(output.scrub("?"), nil, 'utf-8')
    doc.xpath('//img/@src').each do |imgsrc|
      digest = Digest::SHA1.hexdigest(imgsrc)
      
      open(imgsrc) do |f|
        extension = "data"
        type = MIME::Types[f.content_type].first
        if type and type.extensions.length>0 then
          extension = type.extensions[0]
        end

        out_path = File.join(@data_path, digest+"."+extension)
        open(out_path, "w") do |w|
          w.write(f.read())
        end

      end 
    end
  end

  def find_localpath(imgsrc)
    digest = Digest::SHA1.hexdigest(imgsrc)
	  files = Dir.glob(@data_path + "/"+digest+".*")
	  if files.length > 0 then
	  	return files[0]
		end
	  return ""
  end
end


if $0 == __FILE__ then
  if ARGV.length < 1 then
    exit
  end

  config = YAML.load_file('config.yml')
  ActiveRecord::Base.establish_connection(config["db"][ENV['ENV']])
  item = QiitaItem.find_by qiita_id: ARGV[0]

  dl = QiitaImageDownload.new(config['image'])
  dl.download(item)
end
