# frozen_string_literal: true

module Bolt
  module Util
    class << self
      def read_yaml_hash(path, file_name)
        require 'yaml'

        logger = Logging.logger[self]
        path = File.expand_path(path)
        content = File.open(path, "r:UTF-8") { |f| YAML.safe_load(f.read) } || {}
        unless content.is_a?(Hash)
          msg = "Invalid content for #{file_name} file: #{path} should be a Hash or empty, not #{content.class}"
          raise Bolt::FileError.new(msg, path)
        end
        logger.debug("Loaded #{file_name} from #{path}")
        content
      rescue Errno::ENOENT
        raise Bolt::FileError.new("Could not read #{file_name} file: #{path}", path)
      rescue Psych::Exception => e
        raise Bolt::FileError.new("Could not parse #{file_name} file: #{path}\n"\
                                  "Error at line #{e.line} column #{e.column}", path)
      rescue IOError, SystemCallError => e
        raise Bolt::FileError.new("Could not read #{file_name} file: #{path}\n"\
                                  "error: #{e}", path)
      end

      def read_optional_yaml_hash(path, file_name)
        File.exist?(path) ? read_yaml_hash(path, file_name) : {}
      end

      # Accepts a path with either 'plans' or 'tasks' in it and determines
      # the name of the module
      def module_name(path)
        # Remove extra dots and slashes
        path = Pathname.new(path).cleanpath.to_s
        fs = File::SEPARATOR
        regex = Regexp.new("#{fs}plans#{fs}|#{fs}tasks#{fs}")

        # Only accept paths with '/plans/' or '/tasks/'
        unless path.match?(regex)
          msg = "Could not determine module from #{path}. "\
            "The path must include 'plans' or 'tasks' directory"
          raise Bolt::Error.new(msg, 'bolt/modulepath-error')
        end

        # Split the path on the first instance of /plans/ or /tasks/
        parts = path.split(regex, 2)
        # Module name is the last entry before 'plans' or 'tasks'
        modulename = parts[0].split(fs)[-1]
        filename = File.basename(path).split('.')[0]
        # Remove "/init.*" if filename is init or just remove the file
        # extension
        if filename == 'init'
          parts[1].chomp!(File.basename(path))
        else
          parts[1].chomp!(File.extname(path))
        end

        # The plan or task name is the rest of the path
        [modulename, parts[1].split(fs)].flatten.join('::')
      end

      def to_code(string)
        case string
        when Bolt::PAL::YamlPlan::DoubleQuotedString
          string.value.inspect
        when Bolt::PAL::YamlPlan::BareString
          if string.value.start_with?('$')
            string.value.to_s
          else
            "'#{string.value}'"
          end
        when Bolt::PAL::YamlPlan::EvaluableString, Bolt::PAL::YamlPlan::CodeLiteral
          string.value.to_s
        when String
          "'#{string}'"
        when Hash
          formatted = String.new("{")
          string.each do |k, v|
            formatted << "#{to_code(k)} => #{to_code(v)}, "
          end
          formatted.chomp!(", ")
          formatted << "}"
          formatted
        when Array
          formatted = String.new("[")
          formatted << string.map { |str| to_code(str) }.join(', ')
          formatted << "]"
          formatted
        else
          string
        end
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
      def walk_vals(data, skip_top = false, &block)
        data = yield(data) unless skip_top
        if data.is_a? Hash
          data.transform_values { |v| walk_vals(v, &block) }
        elsif data.is_a? Array
          data.map { |v| walk_vals(v, &block) }
        else
          data
        end
      end

      # Accepts a Data object and returns a copy with all hash and array values
      # modified by the given block. Descendants are modified before their
      # parents.
      def postwalk_vals(data, skip_top = false, &block)
        new_data = if data.is_a? Hash
                     data.transform_values { |v| postwalk_vals(v, &block) }
                   elsif data.is_a? Array
                     data.map { |v| postwalk_vals(v, &block) }
                   else
                     data
                   end
        if skip_top
          new_data
        else
          yield(new_data)
        end
      end

      # Performs a deep_clone, using an identical copy if the cloned structure contains multiple
      # references to the same object and prevents endless recursion.
      # Credit to Jan Molic via https://github.com/rubyworks/facets/blob/master/LICENSE.txt
      def deep_clone(obj, cloned = {})
        return cloned[obj.object_id] if cloned.include?(obj.object_id)

        # The `defined?` method will not reliably find the Java::JavaLang::CloneNotSupportedException constant
        # presumably due to some sort of optimization that short-cuts doing a bunch of Java introspection.
        # Java::JavaLang::<...> IS defining the constant (via const_missing or const_get magic perhaps) so
        # it is safe to reference it in the error_types array when a JRuby interpreter is evaluating the code
        # (detected by RUBY_PLATFORM == `java`). SO instead of conditionally adding the CloneNotSupportedException
        # constant to the error_types array based on `defined?` detecting the Java::JavaLang constant it is added
        # based on detecting a JRuby interpreter.
        # TypeError handles unclonable Ruby ojbects (TrueClass, Fixnum, ...)
        # CloneNotSupportedException handles uncloneable Java objects (JRuby only)
        error_types = [TypeError]
        error_types << Java::JavaLang::CloneNotSupportedException if RUBY_PLATFORM == 'java'

        begin
          cl = obj.clone
        rescue *error_types
          cloned[obj.object_id] = obj
          obj
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

          cl
        end
      end

      # This is stubbed for testing validate_file
      def file_stat(path)
        File.stat(File.expand_path(path))
      end

      def snake_name_to_class_name(snake_name)
        snake_name.split('_').map(&:capitalize).join
      end

      def class_name_to_file_name(cls_name)
        # Note this turns Bolt::CLI -> 'bolt/cli' not 'bolt/c_l_i'
        # this won't handle Bolt::Inventory2Foo
        cls_name.gsub(/([a-z])([A-Z])/, '\1_\2').gsub('::', '/').downcase
      end

      def validate_file(type, path, allow_dir = false)
        stat = file_stat(path)

        if !stat.readable?
          raise Bolt::FileError.new("The #{type} '#{path}' is unreadable", path)
        elsif !stat.file? && (!allow_dir || !stat.directory?)
          expected = allow_dir ? 'file or directory' : 'file'
          raise Bolt::FileError.new("The #{type} '#{path}' is not a #{expected}", path)
        elsif stat.directory?
          Dir.foreach(path) do |file|
            next if %w[. ..].include?(file)
            validate_file(type, File.join(path, file), allow_dir)
          end
        end
      rescue Errno::ENOENT
        raise Bolt::FileError.new("The #{type} '#{path}' does not exist", path)
      end

      # Returns true if windows false if not.
      def windows?
        !!File::ALT_SEPARATOR
      end

      # Accept hash and return hash with top level keys of type "String" converted to symbols.
      def symbolize_top_level_keys(hsh)
        hsh.each_with_object({}) { |(k, v), h| k.is_a?(String) ? h[k.to_sym] = v : h[k] = v }
      end
    end
  end
end
