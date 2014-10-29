# encoding: UTF-8

require 'yaml'
require 'sqlite3'

# Old.
require 'fileutils'

# Database Class for saved rss-entries
module SDD
  # Class def
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
        `moved`     boolean
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
    end

    def open
      @db = SQLite3::Database.new(@database_file)
      create_tables
    end

    def close
      @db.close if @db
    end

    def add?(u)
      return true if @db.get_first_row "SELECT id FROM episodes WHERE url LIKE '%#{u}%'"[0]
      false
    end

    # def add?(u)
    #   rs = @db.get_first_row "SELECT id FROM episodes WHERE url LIKE '%#{u}%'"
    #   return true if rs[0] == 0
    #   false
    # end

    def add(item)
      bulk_add([item])
    end

    def bulk_add(items)
      @db.prepare('INSERT INTO `episodes`
        (`show_id`,`season`,`episode`,`url`,`added`,`submitted`,`moved`)
        VALUES (?,?,?,?,?,?,?)'
        ) do |stm|
        items.each do |item|
          stm.execute(
            item['show_id'],
            item['season'],
            item['episode'],
            item['url'],
            item['added'],
            sq_t_f(item['submitted']),
            sq_t_f(item['submitted'])
            )
          stm.close if stm
        end
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
      show_id = move_object.data['info'].n_titleize
      stm = @db.prepare('UPDATE episodes set moved=? WHERE show_id=? AND season=? AND episode=?')
      stm.execute(
        sq_t_f(moved),
        show_id,
        move_object.data['info'].series,
        move_object.data['info'].episode
      )
      stm.close if stm
    end

    def show_id_from_name(name)
      stm = @db.prepare('SELECT id FROM shows WHERE name = ?')
      rs = stm.execute(name)
      result = []
      rs.each { |id | result << [id] }
      stm.close if stm
      result
    end

    def sq_t_f(a)
      (a ? 't' : 'f')
    end
  end
end
