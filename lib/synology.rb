# encoding: UTF-8
require 'open-uri'
require 'cgi'
require 'json'
require 'rest_client'
require 'yaml'

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

    def upload(filename)
      fields = {}
      fields['api'] = 'SYNO.FileStation.Upload'
      fields['version'] = 1
      fields['method'] = 'upload'
      fields['dest_folder_path'] = '/video/Download/'
      fields['_sid'] = @sid

      data = RestClient.post "#{@base}/FileStation/api_upload.cgi", fields.merge('file' => File.new(filename))
      data['success']
    end

    def list(folder_path)
      url_file = 'FileStation/file_share.cgi'
      fields = {}
      fields['_sid'] = @sid
      fields['version'] = 1
      fields['api'] = 'SYNO.FileStation.List'
      fields['method'] = 'list'
      fields['additional'] = 'type'
      fields['folder_path'] = folder_path

      query = URI.encode_www_form(fields).gsub('+', '%20')
      data = RestClient.get "#{@base}/#{url_file}?#{query}"
      data
    end

    #     GET
    # /webapi/FileStation/file_crtfdr.cgi?api=SYNO.FileStation.CreateFolder&version=1&met
    # hod=create&folder_path=%2Fvideo&name=test
    def mkdir(base, path)
      url_file = 'FileStation/file_crtfdr.cgi'
      fields = {}
      fields['_sid'] = @sid
      fields['version'] = 1
      fields['api'] = 'SYNO.FileStation.CreateFolder'
      fields['method'] = 'create'
      fields['folder_path'] = base
      fields['name'] = path
      query = URI.encode_www_form(fields).gsub('+', '%20')
      data = RestClient.get "#{@base}/#{url_file}?#{query}"
      data['success']
    end

    # GET
    # /webapi/FileStation/file_MVCP.cgi?api=SYNO.FileStation.CopyMove&version=1&method=st
    # art&path=%2Fvideo%2Ftest.avi&dest_folder_path=%2F%2Fvideo%2Ftest
    def move(src_file, dst_dir, remove_src = false)
      url_file = 'FileStation/file_MVCP.cgi'
      fields = {}
      fields['_sid'] = @sid
      fields['version'] = 1
      fields['api'] = 'SYNO.FileStation.CopyMove'
      fields['method'] = 'start'
      fields['path'] = src_file
      fields['dest_folder_path'] = dst_dir
      fields['remove_src'] = remove_src
      fields['overwrite'] = false
      query = URI.encode_www_form(fields).gsub('+', '%20')
      data = RestClient.get "#{@base}/#{url_file}?#{query}"
      data['success']
    end
  end
end
