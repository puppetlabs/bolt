# frozen_string_literal: true

require 'fileutils'
require_relative '../../bolt/error'
require_relative '../../bolt/util'

module Bolt
  class Plugin
    class Cache
      attr_reader :reference, :plugin_cache_file, :default_config, :id

      def initialize(reference, plugin_cache_file, default_config)
        @reference = reference
        @plugin_cache_file = plugin_cache_file
        @default_config = default_config
      end

      def read_and_clean_cache
        return if ttl == 0
        validate

        # Luckily we don't need to use a serious hash algorithm
        require 'digest/bubblebabble'
        r = reference.reject { |k, _| k == '_cache' }.sort.to_s
        @id = Digest::SHA2.bubblebabble(r)[0..20]

        unmodified = true
        # First remove any cache entries past their ttl
        # This prevents removing plugins from leaving orphaned cache entries
        cache.delete_if do |_, entry|
          expired = Time.now - Time.parse(entry['mtime']) >= entry['ttl']
          unmodified = false if expired
          expired
        end
        File.write(plugin_cache_file, cache.to_json) unless cache.empty? || unmodified

        cache.dig(id, 'result')
      end

      private def cache
        @cache ||= Bolt::Util.read_optional_json_file(@plugin_cache_file, 'cache')
      end

      def write_cache(result)
        cache.merge!({ id => { 'result' => result,
                               'mtime' => Time.now,
                               'ttl' => ttl } })
        FileUtils.touch(plugin_cache_file)
        File.write(plugin_cache_file, cache.to_json)
      end

      def validate
        # The default cache `plugin-cache` will be validated by the config
        # validator
        return if reference['_cache'].nil?
        r = reference['_cache']
        unless r.is_a?(Hash)
          raise Bolt::ValidationError,
                "_cache must be a Hash, received #{r.class}: #{r.inspect}"
        end

        unless r.key?('ttl')
          raise Bolt::ValidationError, "_cache must set 'ttl' key."
        end

        unless r['ttl'] >= 0
          raise Bolt::ValidationError, "'ttl' key under '_cache' must be a minimum of 0."
        end
      end

      private def ttl
        @ttl ||= reference.dig('_cache', 'ttl') || default_config['ttl']
      end
    end
  end
end
