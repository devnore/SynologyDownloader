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
  attr_reader :database_file , :state_db, :downloader
  attr_writer :downloader

  # rubocop:disable MethodLength
  def initialize(database_file = nil, settings_file = nil)
    FileUtils.mkdir_p(File.dirname(File.expand_path('~/.SynologyDownloader/')))

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
      file.write @state_db.to_yaml
    end
  end

  def open_with_retry(uri, tries = 5) # rubocop:disable MethodLength
    catch :success do
      tries.times do |i|
        begin

          throw :success, open(uri)
        rescue
          print '.'
          sleep(1 / 2)
        end
      end
      return nil
    end
  end

  def load_rss # rubocop:disable MethodLength
    @settings['rss'].each do |k, u|
      print "\nChecking: #{k}"
      open_with_retry(u) do |rss|
        continue if rss.nil?
        feed = RSS::Parser.parse(rss)
        feed.items.each do |item|
          drl = nil
          if !@state_db[item.title] || @state_db[item.title]['done'] == 0
            if k.start_with?('PIRATE-')
              drl = PirateSearch.search(item.title)
            else
              drl = item.link
            end
            @state_db[item.title] = {
              'date' => @now, 'url' => drl, 'done' => false
            } if drl
          end
        end
      end
    end
    print "\n"
  end

  def download_start
    fail('wrong args.') unless @settings['downloader']
    dl = Synology::DSM.new(@settings['downloader'])
    add_downloads(dl) if dl.login
    dl.logout
  end

  def to_s
    'A database of Downloaded stuff...'
  end

  private

  def add_downloads(dl)
    @state_db.each do |key, item|
      next if item['done'] == true
      downloaded_ok = dl.download(item['url'])
      item['done'] = downloaded_ok
    end
  end

  def merge_recursively(a, b)
    a.merge(b) { |key, a_item, b_item| merge_recursively(a_item, b_item) }
  end
end
