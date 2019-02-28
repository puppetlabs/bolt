# frozen_string_literal: true

require 'puppet/util/network_device/base'

module Puppet::Transport # rubocop:disable Style/ClassAndModuleChildren
  class Fake
    def initialize(_context, connection_info)
      @path = connection_info[:path]
    end

    def data
      if File.file? @path
        JSON.parse(File.read(@path))
      else
        {}
      end
    end

    def write(new_data)
      File.write(@path, new_data.to_json)
    end

    def facts(_context)
      {
        'operatingsystem' => 'FakeDevice',
        'exists' => File.exist?(@path),
        'size' => File.size?(@path) || 0
      }
    end

    def get
      data.map do |k, v|
        {
          name: k,
          content: v,
          ensure: 'present'
        }
      end
    end

    def set(path, val, _merge = false)
      new = data
      new[path] = val
      write(new)
    end

    def delete(path)
      new = data
      new.delete(path)
      write(new)
    end
  end
end
