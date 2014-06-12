# encoding: UTF-8
#

module SDD
  #
  class Item
    attr_reader :now , :date, :title, :url, :status
    attr_writer :status
    def initialize(params = {})
      @title = params.fetch('title', nil)
      @date = params.fetch('date', DateTime.now.strftime('%Y-%m-%d'))
      @url = params.fetch('url', nil)
      @status = false
    end
  end
end
