# encoding: utf-8

require 'ostruct'

class OpenStruct
  def to_h
    @table
  end
end

module Configurable
  module Mixin
    attr_reader :config

    def set(name, &block)
      @config ||= OpenStruct.new
      block.call(@config.send("#{name}=", OpenStruct.new))
    end
  end

  module Configuration
    include Configurable
  end
end
