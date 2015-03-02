# encoding: UTF-8

require 'yaml'
require 'sqlite3'
require 'fileutils'

module SDD
  class Database
    include Enumerable
    attr_reader :now, :items
    attr_writer :items

    def initialize(params = {})
      f = params.fetch('file', '~/.SynologyDownloader/sqlite.db')
      @database_file = File.expand_path(f)
    end

    def create_tables
      @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS `episodes` (
        `id`        INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `show_id`   integer,
        `season`    integer,
        `episode`   integer,
        `url`       varchar(255),
        `added`     datetime,
        `submitted` boolean,
        `moved`     boolean,
        `rss_date`  varchar(255)
        );
      SQL

      @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS `shows` (
        `id`        INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        `name`      varchar(255),
        `rss`       varchar(255),
        `active`    boolean,
        `rss_name`  varchar(255)
        );
      SQL

      @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS `show_name_mapper` (
        `id`  INTEGER NOT NULL PRIMARY KEY,
        `rss_showname` varchar(255),
        `toname_showname` varchar(255),
        UNIQUE(rss_showname, toname_showname)
      );
      SQL
    end

    def open
      @db = SQLite3::Database.new(@database_file)
      create_tables
    end

    def close
      @db.close if @db
    end

    def add?(u)
      ret = nil
      stm = @db.prepare('SELECT id FROM episodes WHERE id=?')
      stm.execute(u).each { |id| id.each { |x| ret = x } }
      stm.close if stm
      return false if ret.is_a? Numeric
      true
    end

    def add(item)
      bulk_add([item])
    end

    def bulk_add(items)
      @db.prepare('INSERT INTO `episodes`
        (`id`,`show_id`,`season`,`episode`,`url`,`added`,`submitted`,`moved`,`rss_date`)
        VALUES (?,?,?,?,?,?,?,?,?)'
        ) do |stm|
        items.each do |item|
 #         puts "Adding #{item.show_name}"
          stm.execute(
            item['id'], item['show_id'],
            item['season'], item['episode'],
            item['url'], item['added'],
            sq_t_f(item['submitted']), sq_t_f(item['submitted']),
            item['rss_date']
            )
        end
        stm.close if stm
      end
      add_show_mappings(items)
    end

    def add_show_mapping(item)
      add_show_mappings([item])
    end

    def add_show_mappings(items)
      @db.prepare('INSERT OR IGNORE INTO `show_name_mapper`
        (`id`,`rss_showname`,`toname_showname`)
        VALUES (?,?,?)') do |stm|
        items.each do |item|
          stm.execute(
            item['show_id'].to_i,
            item['show_name'],
            item['toname_show_name']
            )
        end
        stm.close if stm
      end
    end

    def active_rss
      rs = @db.execute "SELECT id, name, rss FROM shows WHERE active LIKE '%t%'"
      result = {}
      rs.each { |id, name, rss| result[id] = { 'name' => name, 'rss' => rss } }
      result
    end

    def process_new
      rs = @db.execute "SELECT id, url FROM episodes WHERE submitted LIKE '%f%'"
      result = []
      rs.each { |id, url| result << [id, url] }
      result
    end

    def set_submitted(id, submitted)
      stm = @db.prepare('UPDATE episodes set submitted=? WHERE id=?')
      stm.execute(sq_t_f(submitted), id)
      stm.close if stm
    end

    def set_moved(id, moved)
      stm = @db.prepare('UPDATE episodes set moved=? WHERE id=?')
      stm.execute(sq_t_f(moved), id)
      stm.close if stm
    end

    def set_moved(move_object, moved)
      return unless move_object.data['type'] == 'series'
      toname_showname = move_object.data['info'].n_titleize

      stm = @db.prepare('SELECT id from `show_name_mapper` where toname_showname LIKE ?')
      rs = stm.execute(toname_showname)
      row = rs.next
      show_id = row[0]
      stm.close if stm

      return if show_id.nil?

      stmt = @db.prepare('UPDATE episodes set moved=? WHERE show_id=? AND season=? AND episode=?')
      stmt.execute(
        sq_t_f(moved),
        show_id,
        move_object.data['info'].series,
        move_object.data['info'].episode
      )
      stmt.close if stmt
    end


    def sq_t_f(a)
      (a ? 't' : 'f')
    end
  end
end
