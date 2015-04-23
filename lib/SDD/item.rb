# encoding: UTF-8
#
require 'to_name'

module SDD
  #
  class Item
    attr_accessor :data

    def initialize(params = {},  ini, dl)
      @ini = ini
      @dl = dl
      @data = { 'filename' => params.fetch('name', nil) }
      @is_root = params.fetch('is_root', false)
      @data['ext'] = params.fetch('additional', {}).fetch('type', nil).upcase
      @data['isdir'] = params.fetch('isdir', nil)
      @data['path'], @data['src'] = params.fetch('path', nil)
      @data['info'] = ToName.to_name(@data['filename'])
      @data['type'] = @data['info'].series.nil? ? 'movies' : 'series'
    end

    def do_move?
      @ini['file']['type']['video'].include?(@data['ext'])
    end

    def get_share(create = true)
      @_share = @ini['shares'][@data['type']]
      @dl.mkdir(@_share['share'], @_share['path'].gsub(/^[\/]+/, '')) if create
      [@_share['share'], @_share['path'].gsub(/^[\/]+/, '')].join('/')
    end

    def prep_move
      if @data['type'] == 'series'
        dest = "#{@data['info'].n_titleize}/Season #{@data['info'].s_pad}/"
      end
      @data['src'] = @is_root ? @data['path'] : File.dirname(@data['path'])
      @share = get_share
      @dl.mkdir(@share, dest)
      @data['dest'] = [@share, dest].join('/')
      @prep_move = true # Temp fix to disallow movies...
    end

    def move
      prep_move unless @prep_move
      @dl.move(@data['src'], @data['dest']) if do_move?
    end
  end
end
