# encoding: UTF-8
require 'open-uri'
require 'nokogiri'

# Search Piratebay
module PirateSearch
  def self.search(name)
    return if name.nil?
    rows = get(name)
    rows.each do |r|
      name = r.search('a.detLink')
      next if name.empty?
      magnet_link = get_magnet(r)
      return magnet_link
    end
    false
  end

  def self.get_magnet(row)
    row.search('td')[1].search('a').each do |a|
      return a['href'] if a['href'].match(/^magnet.*/)
    end
  end

  def self.get_desctiption(row)
    temp = row.search('font.detDesc').text
    match = temp.match(/Uploaded (.*), ULed by .*/)
    match[1]
  end

  def print_post(r, cnt)
    description = get_desctiption(r)
    temp = row.search('td')
    seeders = temp[2].text unless temp[2].nil?
    leechers = temp[3].text unless temp[3].nil?
    print "#{cnt}:\tSE #{seeders},"
    print "LE #{leechers}, Date #{description}\t\t#{name.text}\n"
  end

  def self.get(name)
    search_url = 'http://thepiratebay.org/search/'
    Nokogiri::HTML(open("#{search_url}#{URI.escape(name)}/0/7/0"))
      .xpath('//*[@id="searchResult"]').search('tr')
    rescue
      raise('Piratebay not responding.')
  end
end
