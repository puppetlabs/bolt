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
        # safe_load doesn't work with psych in ruby 2.0
        # The user controls the configfile so this isn't a problem
        # rubocop:disable YAMLLoad
        File.open(path, "r:UTF-8") { |f| YAML.load(f.read) }
      rescue Errno::ENOENT
        if path_passed
          raise Bolt::CLIError, "Could not read #{file_name} file: #{path}"
        end
      # In older releases of psych SyntaxError is not a subclass of Exception
      rescue Psych::SyntaxError
        raise Bolt::CLIError, "Could not parse #{file_name} file: #{path}"
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
    end
  end
end
