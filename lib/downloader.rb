# encoding: UTF-8
# Rss Fetcher

require 'rss'
require 'open-uri'
require 'yaml'
require 'date'
require 'fileutils'
require 'to_name'
require_relative 'SDD'
require_relative 'NAS'

#
module SDD
  # Main Class
  class Downloader
    attr_reader :database_file, :downloader, :dl, :database
    attr_writer :downloader, :dl, :database

    def initialize(params = {})
      @settings_file = File.expand_path(params.fetch(:settings_file, '~/.SynologyDownloader/settings.yml'))
      @settings = load_yml(@settings_file)
      @database = SDD::Database.new(@settings['database'])
      @dl = NAS.get_dl(@settings['NAS'])
      puts "RSS-Downloader #{SDD::VERSION}"
    end

    def run
      @database.open
      load_rss
      if @dl.login
        move_start
        download_start
        @database.save
      else
        puts 'No connection to Server.'
      end

      @dl.logout
    end

    def load_yml(file)
      return  YAML.load_file file
    rescue
      return {}
    end

    private

    def load_rss
      @settings['rss'].each do |k, u|
        print "\nChecking: #{k}..."
        open_with_retry(u) do |rss|
          continue if rss.nil?
          RSS::Parser.parse(rss).items.each do |item|
            @database.add(SDD::Item.new('title' => item.title, 'url' => item.link))
          end
        end
      end
      print "\n"
    end

    def download_start
      @database.each do |key, item|
        next if item.status
        puts "Downloading #{item.title}"
        item.status = @dl.download(item.url)
      end
    end

    def move_start
      path = get_share(@settings['shares']['download'])
      move_process_list(@dl.ls(path), 1)
    end

    def merge_recursively(a, b)
      a.merge(b) { |key, a_item, b_item| merge_recursively(a_item, b_item) }
    end

    def open_with_retry(url, n = 5)
      1.upto(n) do
        begin
          open(url) { |handle| yield handle }
          break
        rescue
          sleep(1 / 2)
        end
      end
    end

    def get_share(share)
      "#{share['share']}#{share['path']}" if dl.mkdir(share['share'], share['path'].gsub(/^[\/]+/, ''))
    end

    def move_process_list(list, depth = 0, parent_is_root = true)
      list['data']['files'].each do |e|
        if e['isdir']
          move_process_list(@dl.ls(e['path']) , depth - 1, false) if depth < 0
        end
        next if process_file_by_ext(e['additional']['type'])
        path = generate_move_data(e, parent_is_root)
        path_base = get_share(@settings['shares'][path['type']])
        dl.mkdir(path_base, path['dest'])
        dl.move(path['src'], "#{path_base}/#{path['dest']}")
      end
    end

    def process_file_by_ext(extention)
      @settings['file']['type']['video'].map! { |c| c.downcase }
      true unless @settings['file']['type']['video'].include?(extention.downcase)
    end

    def generate_move_data(file_info, parent_is_root = true)
      ret = { 'src' => file_info['path'], 'dest' => '' , 'type' => nil }
      info = ToName.to_name(file_info['name'])
      ret['type'] = info.series.nil? ? 'movies' : 'series'

      case ret['type']
      when 'movies'
        ret['src'] = parent_is_root ? file_info['path'] : File.dirname(file_info['path'])
      when 'series'
        ret['dest'] = "#{info.name.gsub(/\w+/, &:capitalize)}/Season #{info.series.to_s.rjust(2, '0')}/"
      end
      ret
    end
  end
end
