# encoding: UTF-8
# Rss Fetcher

require 'rss'
require 'open-uri'
require 'yaml'
require 'date'
require 'pp'
require 'fileutils'
require 'to_name'
require_relative 'synology'
require_relative 'piratesearch'

# Main Class
class SynologyDownloader
  attr_reader :database_file , :state_db, :downloader, :settings_dir, :dl
  attr_writer :downloader, :dl

  def initialize(database_file = nil, settings_file = nil) # rubocop:disable MethodLength
    @settings_dir =  File.expand_path('~/.SynologyDownloader/')
    FileUtils.mkdir_p(File.dirname(@settings_dir))
    database_file ||= File.expand_path('~/.SynologyDownloader/database.yml')
    @database_file = database_file
    settings_file ||= File.expand_path('~/.SynologyDownloader/settings.yml')
    @settings_file = settings_file
    @settings = load_yml(@settings_file)
    @state_db = load_yml(@database_file)
    @now = DateTime.now.strftime('%Y-%m-%d')
  end

  # Run this app
  def run
    @dl = Synology::DSM.new(@settings['downloader'])
    if @dl.login
      move_start
      load_rss
      save_db if download_start
    else
      puts 'No connection to Server.'
    end
  ensure
    @dl.logout
  end

  def load_yml(file)
    return  YAML.load_file file
  rescue
    puts "Error Loading #{file}"
    return {}
  end

  def save_db
    File.open(@database_file, 'w') do |file|
      puts "saving: #{@database_file}"
      file.write @state_db.to_yaml
    end
  end

  def open_with_retry(url, n = 5) # rubocop:disable MethodLength
    1.upto(n) do
      begin
        open(url) do |handle|
          yield handle
        end
        break
      rescue
        print '.'
        sleep(1 / 2)
      end
    end
  end

  def load_rss # rubocop:disable MethodLength
    @settings['rss'].each do |k, u|
      print "\nChecking: #{k}"
      open_with_retry(u) do |rss|
        continue if rss.nil?
        RSS::Parser.parse(rss).items.each do |item|
          if !@state_db[item.title] || @state_db[item.title]['done'] == false
            drl = k.start_with?('PIRATE-') ? PirateSearch.search(item.title) : item.link
            @state_db[item.title] = { 'date' => @now, 'url' => drl, 'done' => false } if drl
          end
        end
      end
    end
    print "\n"
  end

  def download_start
    add_downloads
  end

  def move_start
    path = getshare(@settings['shares']['download'])
    move_process_list(JSON.parse(@dl.list(path)), true, true)
  end

  def move_process_list(list, recursive = false, parent_is_root = true)
    list['data']['files'].each do |e|
      if e['isdir'] && recursive
        move_process_list(JSON.parse(@dl.list(e['path'])) , false, false)
      end
      unless @settings['file']['type']['movie'].include?(e['additional']['type'])
        next
      end
      info = ToName.to_name(e['name'])

      type = info.series.nil? ? 'movies' : 'series'
      path_base = getshare(@settings['shares'][type])

      case type
      when 'movies'
        path = ''
        file_to_move = parent_is_root ? e['path'] : File.dirname(e['path'])
      when 'series'
        path = "#{info.name.gsub(/\w+/, &:capitalize)}/Season #{info.series.to_s.rjust(2, '0')}/"
        dl.mkdir(path_base, path)
        file_to_move = e['path']
      end
      dl.move(file_to_move, "#{path_base}/#{path}" , true)
    end
  end

  private

  def add_downloads
    @state_db.each do |key, item|
      item['done'] = dl.download(item['url']) unless item['done']
    end
  end

  def merge_recursively(a, b)
    a.merge(b) { |key, a_item, b_item| merge_recursively(a_item, b_item) }
  end

  def getshare(share, create = true)
    data = dl.mkdir(share['share'], share['path'].gsub(/^[\/]+/, '')) if create
    "#{share['share']}#{share['path']}"
  end
end
