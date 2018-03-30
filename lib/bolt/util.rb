# frozen_string_literal: true

module Bolt
  module Util
    # CODEREVIEW I hate mixing in random modules
    class << self
      def read_config_file(path, default_paths = nil, file_name = 'file')
        logger = Logging.logger[self]
        path_passed = path
        if path.nil? && default_paths
          found_default = default_paths.select { |p| File.exist?(p) }
          if found_default.size > 1
            logger.warn "Found #{file_name}s at #{found_default.join(', ')}, using the first"
          end
          # Use first found, fall back to first default and try to load even if it didn't exist
          path = found_default.first || default_paths.first
        end

        path = File.expand_path(path)
        File.open(path, "r:UTF-8") { |f| YAML.safe_load(f.read) }
      rescue Errno::ENOENT
        if path_passed
          raise Bolt::CLIError, "Could not read #{file_name} file: #{path}"
        end
      rescue Psych::Exception
        raise Bolt::CLIError, "Could not parse #{file_name} file: #{path}"
      rescue IOError, SystemCallError
        raise Bolt::CLIError, "Could not read #{file_name} file: #{path}"
      end

      def deep_merge(hash1, hash2)
        recursive_merge = proc do |_key, h1, h2|
          if h1.is_a?(Hash) && h2.is_a?(Hash)
            h1.merge(h2, &recursive_merge)
          else
            h2
          end
        end
        hash1.merge(hash2, &recursive_merge)
      end

      def map_vals(hash)
        hash.each_with_object({}) do |(k, v), acc|
          acc[k] = yield(v)
        end
      end

      # Accepts a Data object and returns a copy with all hash keys
      # modified by block. use &:to_s to stringify keys or &:to_sym to symbolize them
      def walk_keys(data, &block)
        if data.is_a? Hash
          data.each_with_object({}) do |(k, v), acc|
            v = walk_keys(v, &block)
            acc[yield(k)] = v
          end
        elsif data.is_a? Array
          data.map { |v| walk_keys(v, &block) }
        else
          data
        end
      end

      # Accepts a Data object and returns a copy with all hash and array values
      # Arrays and hashes including the initial object are modified before
      # their descendants are.
      def walk_vals(data, &block)
        data = yield(data)
        if data.is_a? Hash
          map_vals(data) { |v| walk_vals(v, &block) }
        elsif data.is_a? Array
          data.map { |v| walk_vals(v, &block) }
        else
          data
        end
      end

      # Depth first walk of pcore rich data to convert it into data and boltesque ruby types
      def pcore_to_ruby(data)
        if data.is_a? Hash
          if data['__pcore_value__']
            val = pcore_to_ruby(data['__pcore_value__'])
          else
            val = data.select {|k,v| !["__pcore_type__", "__pcore_value__"].include?(k)}
            val = map_vals(val, &method(:pcore_to_ruby))
          end
          # TODO: this probably can be it's own method bolt_obj(pcore_type, init_val)
          if data['__pcore_type__']
            #require 'pry'; binding.pry
            case data['__pcore_type__']
            when "ResultSet"
              Bolt::ResultSet.from_asserted_hash(val)
            when "Result"
              Bolt::Result.from_asserted_hash(val)
            when "Target"
              Bolt::Target.from_asserted_hash(val)
            when "Error"
              # we probably want a special error class for this
              #Bolt::Error.new(val['msg'], val['kind'], val['details'], val['issue_code'])
              Bolt::PuppetError.from_asserted_hash(val)
            else
              # TODO set up debug logger
              puts "Unexpected Pcore type #{data['__pcore_type__']}"
              val
            end
          else
            val
          end
        elsif data.is_a? Array
          data.map(&method(:pcore_to_ruby))
        else
          data
        end
      end


      # Performs a deep_clone, using an identical copy if the cloned structure contains multiple
      # references to the same object and prevents endless recursion.
      # Credit to Jan Molic via https://github.com/rubyworks/facets/blob/master/LICENSE.txt
      def deep_clone(obj, cloned = {})
        cloned[obj.object_id] if cloned.include?(obj.object_id)

        begin
          cl = obj.clone
        rescue TypeError
          # unclonable (TrueClass, Fixnum, ...)
          cloned[obj.object_id] = obj
          return obj
        else
          cloned[obj.object_id] = cl
          cloned[cl.object_id] = cl

          if cl.is_a? Hash
            obj.each { |k, v| cl[k] = deep_clone(v, cloned) }
          elsif cl.is_a? Array
            cl.collect! { |v| deep_clone(v, cloned) }
          elsif cl.is_a? Struct
            obj.each_pair { |k, v| cl[k] = deep_clone(v, cloned) }
          end

          cl.instance_variables.each do |var|
            v = cl.instance_eval { var }
            v_cl = deep_clone(v, cloned)
            cl.instance_eval { @var = v_cl }
          end

          return cl
        end
      end
    end
  end
end
