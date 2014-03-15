# encoding: UTF-8
require 'open-uri'
require 'cgi'
require 'json'

# Synology Settings
module Synology
  # Class def
  class DSM
    attr_reader :sid

    def initialize(args)
      @username = args['username']
      @password = args['password']
      @base = "http://#{args['host']}:#{args['port']}/webapi"
    end

    def login
      login_url = "#{@base}/auth.cgi?api=SYNO.API.Auth&version=2&method=login&account=#{@username}&passwd=#{@password}&session=DownloadStation&format=sid"
      data = JSON.parse(open(login_url).read)
      @sid = data['data']['sid'] if data['success']
      puts 'Logged in.'
      data['success']
    end

    def logout
      logout_url = "#{@base}/auth.cgi?api=SYNO.API.Auth&method=logout&version=1&session=DownloadStation"
      data = JSON.parse(open(logout_url).read)
      puts 'Logged out'
      data['success']
    end

    def download(u)
      url = CGI.escape(u)
      download_url = "#{@base}/DownloadStation/task.cgi?api=SYNO.DownloadStation.Task&version=1&method=create&_sid=#{@sid}&uri=#{url}"
      data = JSON.parse(open(download_url).read)
      data['success']
    end
  end
end
