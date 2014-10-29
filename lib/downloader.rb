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
      @ini['file']['type']['video'].map(&:downcase)
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
        move_start
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
          new_episodes = []
          @msg << "Checking: #{data['name']}...\n"
          SDD::Rss.parse(data['rss']) do |item|
            next unless @db.add?(item.link)
            new_episodes << SDD::Rss.gen_episode(id, item)
            added << "[Q]: #{data['name']}"
          end
          @db.bulk_add(new_episodes)
        end
      end
      arr.each(&:join)
      @msg << added
    end

    def download_start
      @db.process_new.each do |id, url|
        @db.set_submitted(id, @dl.download(url))
      end
    end

    def move_start
      s = @ini['shares']['download']
      start_dir = [s['share'], s['path'].gsub(/^[\/]+/, '')].join('/')
      move_in_folder(@dl.ls(start_dir), 1)
    end

    def move_in_folder(list, depth = 0, is_root = true)
      return true if depth < 0
      list['data']['files'].each do |e|
        move_in_folder(@dl.ls(e['path']), depth - 1, false) if e['isdir']
        mv_obj = SDD::Item.new(e, is_root, @ini, @dl)
        if mv_obj.do_move?
          if mv_obj.move
            @db.set_moved(mv_obj, true) if mv_obj.data['type'] == 'series'
          end
        end
      end
    end

    def load_yml(file)
      return  YAML.load_file file
    rescue
      return {}
    end
  end
end
