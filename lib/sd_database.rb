# encoding: UTF-8

require 'fileutils'
require 'yaml'

# Database Class for saved rss-entries
module SDDatabase
  # Class def
  class Collection
    include Enumerable

    def initialize(params = {})
      @database_dir = params.fetch(:database_dir, File.expand_path('~/.SynologyDownloader/'))
      @database_file = params.fetch(:database_file, 'database.yml')
    end

    def open
      @database = load_yml("#{@database_dir}#{database_file}")
    end

    def save
      save_db
    end

    def discard
      open
    end

    def each
      @database.each do |i|
        yield(i)
      end
    end

    private

    def load_yml(file)
      return  YAML.load_file file
    rescue
      return {}
    end

    def save_db
      File.open(@database_file, 'w') do |file|
        puts "saving: #{@database_file}"
        file.write @state_db.to_yaml
      end
    end
  end
end
