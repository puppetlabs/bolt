# frozen_string_literal: true

module Bolt
  module Util
    class << self
      # Gets input for an argument.
      def get_arg_input(value)
        if value.start_with?('@')
          file = value.sub(/^@/, '')
          read_arg_file(file)
        elsif value == '-'
          $stdin.read
        else
          value
        end
      end

      # Reads a file passed as an argument to a command.
      def read_arg_file(file)
        File.read(File.expand_path(file))
      rescue StandardError => e
        raise Bolt::FileError.new("Error attempting to read #{file}: #{e}", file)
      end

      def read_yaml_hash(path, file_name)
        require 'yaml'

        logger = Bolt::Logger.logger(self)
        path = File.expand_path(path)
        content = File.open(path, "r:UTF-8") { |f| YAML.safe_load(f.read) } || {}
        unless content.is_a?(Hash)
          raise Bolt::FileError.new(
            "Invalid content for #{file_name} file at #{path}\nContent should be a Hash or empty, "\
            "not #{content.class}",
            path
          )
        end
        logger.trace("Loaded #{file_name} from #{path}")
        content
      rescue Errno::ENOENT
        raise Bolt::FileError.new("Could not read #{file_name} file at #{path}", path)
      rescue Psych::SyntaxError => e
        raise Bolt::FileError.new("Could not parse #{file_name} file at #{path}, line #{e.line}, "\
                                  "column #{e.column}\n#{e.problem}",
                                  path)
      rescue Psych::Exception => e
        raise Bolt::FileError.new("Could not parse #{file_name} file at #{path}\n#{e.message}",
                                  path)
      rescue IOError, SystemCallError => e
        raise Bolt::FileError.new("Could not read #{file_name} file at #{path}\n#{e.message}",
                                  path)
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
        case data
        when Hash
          data.each_with_object({}) do |(k, v), acc|
            v = walk_keys(v, &block)
            acc[yield(k)] = v
          end
        when Array
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
        case data
        when Hash
          data.transform_values { |v| walk_vals(v, &block) }
        when Array
          data.map { |v| walk_vals(v, &block) }
        else
          data
        end
      end

      # Accepts a Data object and returns a copy with all hash and array values
      # modified by the given block. Descendants are modified before their
      # parents.
      def postwalk_vals(data, skip_top = false, &block)
        new_data = case data
                   when Hash
                     data.transform_values { |v| postwalk_vals(v, &block) }
                   when Array
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
          # We can't recurse on frozen objects to populate them with cloned
          # data. Instead we store the freeze-state of the original object,
          # deep_clone, then set the cloned object to frozen if the original
          # object was frozen
          frozen = obj.frozen?
          cl = begin
            obj.clone(freeze: false)
          # Some datatypes, such as FalseClass, can't be unfrozen. These
          # aren't the types we recurse on, so we can leave them frozen
          rescue ArgumentError => e
            if e.message =~ /can't unfreeze/
              obj.clone
            else
              raise e
            end
          end
        rescue *error_types
          cloned[obj.object_id] = obj
          obj
        else
          cloned[obj.object_id] = cl
          cloned[cl.object_id] = cl

          case cl
          when Hash
            obj.each { |k, v| cl[k] = deep_clone(v, cloned) }
          when Array
            cl.collect! { |v| deep_clone(v, cloned) }
          when Struct
            obj.each_pair { |k, v| cl[k] = deep_clone(v, cloned) }
          end

          cl.instance_variables.each do |var|
            v = cl.instance_variable_get(var)
            v_cl = deep_clone(v, cloned)
            cl.instance_variable_set(var, v_cl)
          end

          cl.freeze if frozen
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

      # Returns true if running in PowerShell.
      def powershell?
        !!ENV['PSModulePath']
      end

      # Accept hash and return hash with top level keys of type "String" converted to symbols.
      def symbolize_top_level_keys(hsh)
        hsh.each_with_object({}) { |(k, v), h| k.is_a?(String) ? h[k.to_sym] = v : h[k] = v }
      end

      # Recursively searches a data structure for plugin references
      def references?(input)
        case input
        when Hash
          input.key?('_plugin') || input.values.any? { |v| references?(v) }
        when Array
          input.any? { |v| references?(v) }
        else
          false
        end
      end

      def unix_basename(path)
        raise Bolt::ValidationError, "path must be a String, received #{path.class} #{path}" unless path.is_a?(String)
        path.split('/').last
      end

      def windows_basename(path)
        raise Bolt::ValidationError, "path must be a String, received #{path.class} #{path}" unless path.is_a?(String)
        path.split(%r{[/\\]}).last
      end

      # Prompts yes or no, returning true for yes and false for no.
      #
      def prompt_yes_no(prompt, outputter)
        choices = {
          'y'   => true,
          'yes' => true,
          'n'   => false,
          'no'  => false
        }

        loop do
          outputter.print_prompt("#{prompt} ([y]es/[n]o) ")
          response = $stdin.gets.to_s.downcase.chomp

          if choices.key?(response)
            return choices[response]
          else
            outputter.print_prompt_error("Invalid response, must pick [y]es or [n]o")
          end
        end
      end
    end
  end
end
