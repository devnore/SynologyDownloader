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

  def e_pad
    @episode.to_s.rjust(2, '0')
  end

  def n_titleize
    @name.gsub(/\w+/, &:capitalize)
  end
end

module SDD
  class Downloader
    attr_reader :msg, :database_file, :downloader, :dl, :database
    attr_writer :msg, :downloader, :dl, :database

    def initialize(params = {})
      f = params.fetch(:settings_file, '~/.SynologyDownloader/settings2.yml')
      @ini = load_yml(File.expand_path(f))
      @db = SDD::Database.new(@ini['database'])
      @dl = NAS.get_dl(@ini['NAS'])
      @msg = []
      puts version
    end

    def version
      "RSS-Downloader #{SDD::VERSION}"
    end

    def run
      @db.open
      process_rss
      if @dl.login
        # move_start
        download_start
        @db.close
      else
        puts 'No connection to Server.'
      end
      @dl.logout
    end

    private

    def process_rss
      arr = []
      added = []
      @db.active_rss.each do |id, data|
        arr << Thread.new do
          @msg << "Checking: #{data['name']}...\n"
          open_with_retry(data['rss']) do |rss|
            new_episodes = []
            continue if rss.nil?
            RSS::Parser.parse(rss).items.each do |item|
              if @db.add?(item.link)
                info = ToName.to_name(item.title)
                new_episodes << {
                  'show_id' =>  id,
                  'season' =>  info.series,
                  'episode' =>  info.episode,
                  'url' => item.link,
                  'added' => Time.now.to_s,
                  'submitted' => false,
                  'moved' => false
                }
                added << "[Q]: #{data['name']} #{info.series}x#{info.episode} "
              end
            end
            @db.bulk_add(new_episodes)
          end
        end
      end
      arr.each { |t| t.join; }
      @msg << added
    end

    def download_start
      @db.process_new.each do |id, url|
        @db.set_submitted(id, @dl.download(url))
      end
    end

    def move_start
      move_process_list(@dl.ls(get_share(@ini['shares']['download'])), 1)
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

    def move_process_list(list, depth = 0, p_is_root = true)
      return true if depth < 0
      list['data']['files'].each do |e|
        move_process_list(@dl.ls(e['path']) , depth - 1, false) if e['isdir']

        # unless (rewrite to return true if it should be processed)
        next if process_file_by_ext(e['additional']['type'])

        p = generate_move_data(e, p_is_root)
        pbase = get_share(@ini['shares'][p['type']])

        dl.mkdir(pbase, p['dest'])
        dl.move(p['src'], "#{pbase}/#{path['dest']}")
      end
    end

    # This is the wrong way around?
    def process_file_by_ext(extention)
      @ini['file']['type']['video'].map! { |c| c.downcase }
      true unless @ini['file']['type']['video'].include?(extention.downcase)
    end

    def generate_move_data(e, p_is_root = true)
      info = ToName.to_name(e['name'])
      ret = {
        'src' => e['path'],
        'dest' => '',
        'type' => info.series.nil? ? 'movies' : 'series'
      }
      case ret['type']
      when 'movies'
        ret['src'] = p_is_root ? e['path'] : File.dirname(e['path'])
      when 'series'
        ret['dest'] = "#{info.n_titleize}/Season #{info.s_pad}/"
      end
      ret
    end

    def get_share(s)
      "#{s['share']}#{s['path']}" if dl.mkdir(s['share'], s['path'].gsub(/^[\/]+/, ''))
    end

    def load_yml(file)
      return  YAML.load_file file
    rescue
      return {}
    end
  end
end
