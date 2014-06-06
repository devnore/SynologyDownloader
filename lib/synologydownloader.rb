# encoding: UTF-8
# Rss Fetcher

require 'rss'
require 'open-uri'
require 'yaml'
require 'date'
require 'pp'
require 'fileutils'
require_relative 'synology'
require_relative 'piratesearch'

# Main Class
class SynologyDownloader
  attr_reader :database_file , :state_db, :downloader, :settings_dir
  attr_writer :downloader

  def initialize(database_file = nil, settings_file = nil) # rubocop:disable MethodLength
    @settings_dir =  File.expand_path('~/.SynologyDownloader/')
    @temp_dir = File.expand_path("#{@settings_dir}/temp/")
    FileUtils.mkdir_p(File.dirname(@settings_dir))
    FileUtils.mkdir_p(File.dirname(@temp_dir))

    database_file ||= File.expand_path('~/.SynologyDownloader/database.yml')

    @database_file = database_file
    settings_file ||= File.expand_path('~/.SynologyDownloader/settings.yml')
    @settings_file = settings_file

    @settings = load_yml(@settings_file)
    @state_db = load_yml(@database_file)
    @now = DateTime.now.strftime('%Y-%m-%d')
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
    fail('wrong args.') unless @settings['downloader']
    dl = Synology::DSM.new(@settings['downloader'])
    if dl.login
      add_downloads(dl)
    else
      puts 'No connection to Server.'
    end
    dl.logout
  end

  def move_start
    dl = Synology::DSM.new(@settings['downloader'])
    if dl.login
      move_process_list(dl, JSON.parse(dl.list(@settings['downloader']['base_dir'])), true, true)
    else
      puts 'No connection to Server.'
    end
    dl.logout
  end

  def move_process_list(dl, list, recursive = false, parent_is_root = true)
    list['data']['files'].each do |e|
      if e['isdir'] && recursive
        move_process_list(dl, JSON.parse(dl.list(e['path'])) , false, false)
      end
      unless @settings['file']['type']['movie'].include?(e['additional']['type'])
        next
      end
      info = ToName.to_name(e['name'])
      if info.series.nil? && info.episode.nil?
        puts dl.mkdir(@settings['downloader']['movies'], 'Incomming/')
        if parent_is_root
          file_to_move = e['path']
        else
          file_to_move = File.dirname(e['path'])
        end
        puts dl.move(file_to_move, "#{@settings['downloader']['movies']}/Incomming/" , true)
      else
        dl.mkdir(@settings['downloader']['series'], "#{info.name}/Season #{info.series.to_s.rjust(2, '0')}/")
        puts dl.move(e['path'], "#{@settings['downloader']['series']}/#{info.name}/Season #{info.series.to_s.rjust(2, '0')}/", true)
      end
    end
  end

  def to_s
    'A database of Downloaded stuff...'
  end

  private

  def add_downloads(dl)
    @state_db.each do |key, item|
      item['done'] = dl.download(item['url']) unless item['done']
    end
  end

  def merge_recursively(a, b)
    a.merge(b) { |key, a_item, b_item| merge_recursively(a_item, b_item) }
  end
end
