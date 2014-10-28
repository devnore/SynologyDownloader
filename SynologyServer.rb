#!/usr/bin/env ruby
# encoding: UTF-8

$LOAD_PATH.unshift '.'
require_relative 'lib/downloader.rb'
require 'sinatra'
require 'yaml'

Signal.trap('INT') {}

fetcher = SDD::Downloader.new

get '/' do
  'Welcome to SynologyDownloader API'
end

get '/run' do
  fetcher.run
  msg = fetcher::msg
  fetcher::msg = []
  msg.to_json
end

# get /check/:show|all

# p /shows/add/:show/:rss

# p /shows/:show/edit/enable
# p /shows/:show/edit/disable
# g /shows/:show|all/check
# g /shows/:show|all/list/new
# g /shows/:show/add/:season/:episode/:url
# g /shows/:show/:episode/download
# g /shows/:show/:episode/downloaded
# g /shows/:show/:episode/delete/[all|downloaded|]  # <----- HOW to do this neat.
# p /shows/:show/:episode/move
# g /shows/:show/:episode/moved

# movies
# p /movie/add/:title/:url
# g /movie/:movie/download
# g /movie/:movie/downloaded
# p /movie/:movie/move
# g /movie/:movie/moved

# p /movie/:show/edit/disable
# g /movie/:show|all/check
# g /movie/:show|all/list/new
# g /movie/:show/add/:season/:episode/:url

