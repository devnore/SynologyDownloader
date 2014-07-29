# encoding: UTF-8
require 'open-uri'
require 'cgi'
require 'json'
require 'rest_client'
require 'yaml'

# Synology Settings
module NAS
  # Class def
  class Synology
    def initialize(args)
      @username = args['username']
      @password = args['password']
      @base = "http://#{args['host']}:#{args['port']}/webapi"
      @fields = { 'version' => 1 }
      @logged_in = false
    end

    def login
      return true if @logged_in
      url_file = 'auth.cgi'
      f = { 'api' => 'SYNO.API.Auth', 'method' => 'login',
            'version' => '2', 'format' => 'sid',
            'account' => @username, 'passwd' => @password,
            'session' => 'DownloadStation'  }
      res = _get(url_file, @fields.merge(f))
      @fields['_sid'] = res['data']['sid']
      @logged_in =  @fields['_sid'].nil? ? 'false' : true
      @logged_in
    end

    def logout
      url_file = 'auth.cgi'
      f = { 'api' => 'SYNO.API.Auth', 'method' => 'logout',
            'session' => 'DownloadStation' }
      _get(url_file, @fields.merge(f))['success']
    ensure
      @fields['_sid'] = nil
    end

    def download(url)
      return false unless @logged_in
      url_file = 'DownloadStation/task.cgi'
      f = { 'api' => 'SYNO.DownloadStation.Task', 'method' => 'create',
            'uri' => url }
      _get(url_file, @fields.merge(f))['success']
    end

    def ls(folder_path)
      return false unless @logged_in
      url_file = 'FileStation/file_share.cgi'
      f = { 'api' => 'SYNO.FileStation.List', 'method' => 'list',
            'additional' => 'type', 'folder_path' => folder_path }
      _get(url_file, @fields.merge(f))
    end

    def mkdir(base, path)
      return false unless @logged_in
      url_file = 'FileStation/file_crtfdr.cgi'
      f = { 'api' => 'SYNO.FileStation.CreateFolder', 'method' => 'create',
            'folder_path' => base, 'name' => path }
      _get(url_file, @fields.merge(f))['success']
    end

    def move(src_file, dst_dir, remove_src = true)
      return false unless @logged_in
      url_file = 'FileStation/file_MVCP.cgi'
      f = {
        'api' => 'SYNO.FileStation.CopyMove', 'method' => 'start',
        'path' => src_file, 'dest_folder_path' => dst_dir,
        'remove_src' => remove_src, 'overwrite' => false
      }
      _get(url_file, @fields.merge(f))['success']
    end

    private

    def _get(url, f)
      query = URI.encode_www_form(f).gsub('+', '%20')
      JSON.parse(RestClient.get("#{@base}/#{url}?#{query}").to_s)
    end
  end
end
