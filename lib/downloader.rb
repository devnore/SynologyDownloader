# encoding: UTF-8
# Rss Fetcher

require 'rss'
require 'simple-rss'
require 'open-uri'
require 'yaml'
require 'date'
require 'fileutils'
# require 'to_name'
require 'benchmark'
require 'parallel'

require_relative 'SDD'
require_relative 'NAS'
require_relative 'toname/to_name'

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
      f = params.fetch(:settings_file, '~/.SynologyDownloader/settings.yml')
      @ini = load_yml(File.expand_path(f))
      @ini['file']['type']['video'].map(&:downcase)
      @db = SDD::Database.new(@ini['database'])
      @dl = NAS.get_dl(@ini['NAS'])
      @msg = []
      @workers = Parallel.processor_count - 1
      puts version
    end

    def version
      "RSS-Downloader #{SDD::VERSION}"
    end

    def run
      @db.open
      process_rss
      if @dl.login
        process_move(1)
        download_start
      else
        puts 'No connection to Server.'
      end
      @dl.logout
      @db.close
    end

    private

    def download_start
      @db.process_new.each do |id, url|
       @db.set_submitted(id, @dl.download(url))
     end
   end

   def process_rss
    added = []
    @db.active_rss.each do |id, data|
      print "Checking: #{data['name']}...\n"
      new_episodes = []
      SimpleRSS.item_tags << :"showrss:showid"
      SimpleRSS.item_tags << :"showrss:episode"
      SimpleRSS.item_tags << :"showrss:showname"

      rss = SimpleRSS.parse open(data['rss'])
      rss.items.each do  |item|
        next unless @db.add?(item.showrss_episode.to_i)
        ep = SDD::Rss.gen_episode(item)
        next unless ep
        new_episodes << ep
        @msg << "[Q]: #{item.showrss_showname} | S#{ep['season']}E#{ep['episode']}"
      end

      @db.bulk_add(new_episodes)
    end
    @msg << added
  end

  def process_move(depth)
    msg = []
    s = @ini['shares']['download']
    start_dir = [s['share'], s['path'].gsub(/^[\/]+/, '')].join('/')
    items = move_list(start_dir, depth, true)

    items.each do |file|
      mv_obj = SDD::Item.new(file, @ini, @dl)

      next unless mv_obj.prep_move

      if mv_obj.data['type'] == 'series'
        if mv_obj.move
          @db.set_moved(mv_obj, true) if mv_obj.data['type'] == 'series'
          msg << "Moved: #{mv_obj.data['info']}"
        else
          puts "#{mv_obj.data['path']} was not moved. #{mv_obj.data['info']}"
        end
      end
    end
    puts msg
  end

  def move_list(path, depth, is_root = false)
    return [] if depth < 0 || path.nil?
    items = []
    li = @dl.ls(path)
    li['data']['files'].each do |data|
      data['is_root'] = is_root
      if @ini['file']['type']['video'].include?(data['additional']['type'])
        items << data unless data['isdir']
      end
      if data['isdir']
        ret = move_list(data['path'], depth - 1)
        items.concat(ret) if ret.is_a?(Array)
      end
    end
    items
  end

  def load_yml(file)
    return  YAML.load_file file
  rescue
    return {}
  end
end
end
