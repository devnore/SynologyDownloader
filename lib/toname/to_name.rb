# encoding: UTF-8
require 'file_name_info'

#
class ToName
  FILE_SEP_REGEX = /\//
  FILE_EXT_SEP_REGEX = /\./
  # Chars used in filenames as a substitute for spaces
  SPACE_SUB_REGEX = /(\.|_|\-)/
  # SPACE_SUB_REGEX = /(\.|_)/
  VIDEO_TYPE_NAMES = [
    'DVDRIP', '1080p', '720p','R5', 'DVDSCR', 'BDRip', 'CAM',
    'TS', 'PPV', 'Xvid', 'divx', 'DVDSCREENER', 'HDTV', 'x264','LOL','PROPER', 'VTV',
    'DIMENSION', 'PROPER', 'ASAP', '2HD', 'RiVER', 'TLA', 'FoV', 'EVOLVE'
  ]

  CONTENT_SOURCE_FOLDER_TEST_REGEX = /#{VIDEO_TYPE_NAMES.join('|')}/i
  CONTENT_SOURCE_REGEX = /(\(|\[|\s)+(#{VIDEO_TYPE_NAMES.join('|')})(\)|\]|\s|$)+/i

  YEAR_REGEX = /(\(|\[|\s)+(19|20)\d{2}(,|\)|\]|\s|$)+/

  SESSION_ESP_REGEX_1 = /S(\d{2})\s?E(\d{2})/i
  SESSION_REGEXS = [
    /S(\d{2})\s?E(\d{2})/i,
    /\s+(\d+)x(\d+)(\s|$)+/i,
    /Season (\d+) Episode (\d+)/i,
    /(\d{2})(\d{2})/i,
    /(\d{1})(\d{2})/i,
  ]

   def self.to_name(location)
    raw_name = self.get_file_name(location)
    session = nil

    # Check to see if we are better off looking at the folder name
    check_extention = true
    unless raw_name =~ CONTENT_SOURCE_REGEX || raw_name =~ SESSION_ESP_REGEX_1
      parent_folder = self.parent_folder_name(location)
      if parent_folder && parent_folder =~ CONTENT_SOURCE_FOLDER_TEST_REGEX
        raw_name = parent_folder
        check_extention = false
      end
    end

    # Remove anything at the start of the name surrounded by [], sometimes there is website name url
    raw_name = raw_name.gsub(/^\[[^\]]+\]/, '')

    # Remove file extention
    raw_name = raw_name[0, raw_name.rindex(FILE_EXT_SEP_REGEX)] if check_extention && raw_name =~ FILE_EXT_SEP_REGEX
    # Remove space sub chars
    raw_name = raw_name.gsub(SPACE_SUB_REGEX, ' ').strip

    name = raw_name.dup
    # Chop off any info about the movie format or source
    name = $` if name =~ CONTENT_SOURCE_REGEX

    # Strip LIMITED off the end.  Note: This is case sensitive
    name = $` if name =~ /LIMITED|LiMiTED$/

    name2 = name.dup
    # Extract year if it's in the filename
    if name2 =~ YEAR_REGEX && name2.index(YEAR_REGEX) > 0 && session.nil?
      i = name2.index(YEAR_REGEX) + 5
      name2 = $`
      rest =  name[i..-1]
      year = $&.gsub(/\(|\)|\[|\]/, '').to_i
      name = "#{name2}#{rest}"
    end

    # Try to extract the session and episode And readd Year if it was removed.
    session = nil
    episode = nil
    SESSION_REGEXS.each do |session_regex|
      if name =~ session_regex
        name = $`
        session = $1.to_i
        episode = $2.to_i
        name = "#{name}#{year}" unless rest.nil?
        puts name
        year = nil # When the year is present with the series info assume it's part of the title
        break
      end
    end

    name.strip!
    FileNameInfo.new(:raw_name => raw_name, :name => name, :year => year,
      :series => session, :episode => episode, :location => location)
  end

  def self.get_file_name(location)
    file_name = location.dup
    # Change to just the filename
    file_name = file_name[file_name.rindex(FILE_SEP_REGEX) + 1, file_name.length] if file_name =~ FILE_SEP_REGEX
    file_name
  end

  def self.parent_folder_name(location)
    # Remove first / and break by folder name
    folders = location.sub(/^\//, '').split('/')
    return nil if folders.empty? || folders.size < 2
    parent_folder = folders[folders.size - 2]
    # If the folder is a CD folder e.g. CD1 go up 1 more
    return folders[folders.size - 3] if folders.size > 2 && parent_folder  =~ /CD\d/i
    parent_folder
  end
end
