# encoding: UTF-8

module SDD
  class Rss
    def self.get(url, n = 5)
      1.upto(n) do
        begin
          open(url) { |handle| yield handle unless handle.nil? }
          break
        rescue
          sleep(1 / 2)
        end
      end
    end

    def self.parse(url, n = 5)
      get(url, n) do |rss|
        RSS::Parser.parse(rss).items.each { |handle| yield handle }
      end
    end

    def self.gen_episode(id, item)
      # Id older than x days... skip the mofo
      return false if (Time.now - Time.parse(item.pubDate.to_s)) / 86_400 > 30
      info = ToName.to_name(item.title)
      p = {
        'show_id' =>  id, 'season' =>  info.series,
        'episode' =>  info.episode, 'url' => item.link,
        'added' => Time.now.to_s, 'submitted' => false,
        'moved' => false, 'rss_date' => item.pubDate.to_s
      }
      p
    end
  end
end
