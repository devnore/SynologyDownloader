# encoding: UTF-8

require 'fileutils'
require 'yaml'

# Database Class for saved rss-entries
module SDD
  # Class def
  class Database
    include Enumerable
    attr_reader :now , :items
    attr_writer :items

    def initialize(params = {})
      f = params.fetch('file', '~/.SynologyDownloader/database_new.yml')
      @database_file = File.expand_path(f)
      @now = DateTime.now.strftime('%Y-%m-%d')
    end

    def open
      @items = load_db
    end

    def discard
      open
    end

    def save
      save_db
    end

    def add(item)
      return false unless item.instance_of?(SDD::Item)
      return false if @items.key?(item.title)
      @items[item.title] = item
      true
    end

    def delete(item)
      false unless @items.key?(item.title)
      @item.delete(item.title)
    end

    def replace(item)
      false unless @items.key?(item.title)
      @items[item.title] = item
    end

    def each
      @items.each do |i|
        yield(i)
      end
    end

    private

    def load_db
      return  YAML.load_file @database_file
    rescue
      return {}
    end

    def save_db
      File.open(@database_file, 'w') do |file|
        file.write @items.to_yaml
      end
    end
  end
end
