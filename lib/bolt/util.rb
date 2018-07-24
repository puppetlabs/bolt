# frozen_string_literal: true

module Bolt
  module Util
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
        content = File.open(path, "r:UTF-8") { |f| YAML.safe_load(f.read) }
        logger.debug("Loaded #{file_name} from #{path}")
        content
      rescue Errno::ENOENT
        msg = "Could not read #{file_name} file: #{path}"
        if path_passed
          raise Bolt::FileError.new(msg, path)
        else
          logger.debug(msg)
          nil
        end
      rescue Psych::Exception
        raise Bolt::FileError.new("Could not parse #{file_name} file: #{path}", path)
      rescue IOError, SystemCallError
        raise Bolt::FileError.new("Could not read #{file_name} file: #{path}", path)
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
            v = cl.instance_variable_get(var)
            v_cl = deep_clone(v, cloned)
            cl.instance_variable_set(var, v_cl)
          end

          return cl
        end
      end

      # Returns true if windows false if not.
      def windows?
        !!File::ALT_SEPARATOR
      end
    end
  end
end
