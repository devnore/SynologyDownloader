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

# Adding two functions. pad season and titelize name
class FileNameInfo
  def s_pad
    @series.to_s.rjust(2, '0')
  end

  def n_titleize
    @name.gsub(/\w+/, &:capitalize)
  end
end

#
module SDD
  # Main Class
  class Downloader
    attr_reader :database_file, :downloader, :dl, :database
    attr_writer :downloader, :dl, :database

    def initialize(params = {})
      f = params.fetch(:settings_file, '~/.SynologyDownloader/settings.yml')
      @ini = load_yml(File.expand_path(f))
      @db = SDD::Database.new(@ini['database'])
      @dl = NAS.get_dl(@ini['NAS'])
      puts "RSS-Downloader #{SDD::VERSION}"
    end

    def run
      @db.open
      load_rss
      if @dl.login
        move_start
        download_start
        @db.save
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
      @ini['rss'].each do |k, u|
        print "Checking: #{k}...\n"
        open_with_retry(u) do |rss|
          continue if rss.nil?
          RSS::Parser.parse(rss).items.each do |item|
            @db.add(SDD::Item.new('title' => item.title, 'url' => item.link))
          end
        end
      end
    end

    def download_start
      @db.each do |key, item|
        next if item.status
        puts "New Item: #{item.title}"
        item.status = @dl.download(item.url)
      end
    end

    def move_start
      path = get_share(@ini['shares']['download'])
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

    def get_share(s)
      if dl.mkdir(s['share'], s['path'].gsub(/^[\/]+/, ''))
        "#{s['share']}#{s['path']}"
      end
    end

    def move_process_list(list, depth = 0, p_is_root = true)
      return true if depth < 0
      list['data']['files'].each do |e|
        move_process_list(@dl.ls(e['path']) , depth - 1, false) if e['isdir']

        next if process_file_by_ext(e['additional']['type'])

        path = generate_move_data(e, p_is_root)
        path_base = get_share(@ini['shares'][path['type']])

        dl.mkdir(path_base, path['dest'])
        dl.move(path['src'], "#{path_base}/#{path['dest']}")
      end
    end

    def process_file_by_ext(extention)
      @ini['file']['type']['video'].map! { |c| c.downcase }
      true unless @ini['file']['type']['video'].include?(extention.downcase)
    end

    def generate_move_data(e, p_is_root = true)
      info = ToName.to_name(e['name'])
      ret = { 'src' => e['path'], 'dest' => '',
              'type' => info.series.nil? ? 'movies' : 'series' }

      case ret['type']
      when 'movies'
        ret['src'] = p_is_root ? e['path'] : File.dirname(e['path'])
      when 'series'
        ret['dest'] = "#{info.n_titleize}/Season #{info.s_pad}/"
      end
      ret
    end
  end # End class
end # End module
