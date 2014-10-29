# encoding: UTF-8

#
module NAS
  require_relative './NAS/synology'
  #
  # This needs to be dynamic.... (if other types of nas should be supported.)
  def self.get_dl(settings)
    settings.each do |_k, value|
      return NAS::Synology.new(value['settings'])
    end
  end
  #
end
