# encoding: UTF-8
# Rss Fetcher

require 'rss'
require 'open-uri'
require 'yaml'
require 'date'
require 'fileutils'
require 'to_name'
require 'benchmark'
require 'parallel'

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
        @db.close
      else
        puts 'No connection to Server.'
      end
      @dl.logout
    end

    private

    def download_start
      Parallel.each(@db.process_new, in_processes: @workers, progress: 'Processing new Downloads') do |id, url|
      #@db.process_new.each do |id, url|
        @db.set_submitted(id, @dl.download(url))
      end
    end

    def process_rss
      added = []
      # @db.active_rss.each do |id, data|
      Parallel.each(@db.active_rss, in_processes: @workers, progress: 'Checking RSS') do |id, data|
        @msg << "Checking: #{data['name']}...\n"
        new_episodes = []
        SDD::Rss.parse(data['rss']) do |item|
          next unless @db.add?(item.link)
          new_episodes << SDD::Rss.gen_episode(id, item)
          added << "[Q]: #{data['name']} | #{item.link}"
        end
        @db.bulk_add(new_episodes)
      end
      @msg << added
    end

    def process_move(depth)
      s = @ini['shares']['download']
      start_dir = [s['share'], s['path'].gsub(/^[\/]+/, '')].join('/')
      items = move_list(start_dir, depth, true)

      Parallel.each(items, in_processes: @workers, progress: 'Moving') do |file|
        mv_obj = SDD::Item.new(file, @ini, @dl)
        if mv_obj.do_move?
          if mv_obj.move
            @db.set_moved(mv_obj, true) if mv_obj.data['type'] == 'series'
          else
            puts "#{mv_obj.data['path']} was not moved"
          end
        end
      end
    end

    def move_list(path, depth, is_root = false)
      return [] if depth < 0 || path.nil?
      items = []
      li = @dl.ls(path)
      li['data']['files'].each do |data|
        data['is_root'] = is_root
        items << data unless data['isdir']
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
