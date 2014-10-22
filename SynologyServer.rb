#!/usr/bin/env ruby
# encoding: UTF-8

$LOAD_PATH.unshift '.'
require_relative 'lib/downloader.rb'
require 'sinatra'
require 'yaml'

Signal.trap('INT') {}

fetcher = SDD::Downloader.new

get '/' do
  'Welcome to SynologyDownloader API<br> <a href="/run">Check after new items</a>'
end

get '/run' do
  fetcher.run
  msg = fetcher::msg.join('<br>')
  fetcher::msg = []
  msg
end

