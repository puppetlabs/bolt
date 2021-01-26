# frozen_string_literal: true

module Bolt
  class NoImplementationError < Bolt::Error
    def initialize(target, task)
      msg = "No suitable implementation of #{task.name} for #{target.name}"
      super(msg, 'bolt/no-implementation')
    end
  end

  class Task
    STDIN_METHODS       = %w[both stdin].freeze
    ENVIRONMENT_METHODS = %w[both environment].freeze

    METADATA_KEYS = %w[description extensions files implementations
                       input_method parameters private puppet_task_version
                       remote supports_noop].freeze

    attr_reader :name, :files, :metadata, :remote

    # name [String] name of the task
    # files [Array<Hash>] where each entry includes `name` and `path`
    # metadata [Hash] task metadata
    def initialize(name, metadata = {}, files = [], remote = false)
      @name = name
      @metadata = metadata
      @files = files
      @remote = remote
      @logger = Bolt::Logger.logger(self)

      validate_metadata
    end

    def self.from_task_signature(task_sig)
      hash = task_sig.task_hash
      new(hash['name'], hash.fetch('metadata', {}), hash.fetch('files', []))
    end

    def remote_instance
      self.class.new(@name, @metadata, @files, true)
    end

    def description
      metadata['description']
    end

    def parameters
      metadata['parameters']
    end

    def parameter_defaults
      (parameters || {}).each_with_object({}) do |(name, param_spec), defaults|
        defaults[name] = param_spec['default'] if param_spec.key?('default')
      end
    end

    def supports_noop
      metadata['supports_noop']
    end

    def module_name
      name.split('::').first
    end

    def tasks_dir
      File.join(module_name, 'tasks')
    end

    def file_map
      @file_map ||= files.each_with_object({}) { |file, hsh| hsh[file['name']] = file }
    end
    private :file_map

    # This provides a method we can override in subclasses if the 'path' needs
    # to be fetched or computed.
    def file_path(file_name)
      file_map[file_name]['path']
    end

    def implementations
      metadata['implementations']
    end

    # Returns a hash of implementation name, path to executable, input method (if defined),
    # and any additional files (name and path)
    def select_implementation(target, provided_features = [])
      impl = if (impls = implementations)
               available_features = target.feature_set + provided_features
               impl = impls.find do |imp|
                 remote_impl = imp['remote']
                 remote_impl = metadata['remote'] if remote_impl.nil?
                 Set.new(imp['requirements']).subset?(available_features) && !!remote_impl == @remote
               end
               raise NoImplementationError.new(target, self) unless impl
               impl = impl.dup
               impl['path'] = file_path(impl['name'])
               impl.delete('requirements')
               impl
             else
               raise NoImplementationError.new(target, self) unless !!metadata['remote'] == @remote
               name = files.first['name']
               { 'name' => name, 'path' => file_path(name) }
             end

      inmethod = impl['input_method'] || metadata['input_method']
      impl['input_method'] = inmethod unless inmethod.nil?

      mfiles = impl.fetch('files', []) + metadata.fetch('files', [])
      dirnames, filenames = mfiles.partition { |file| file.end_with?('/') }
      impl['files'] = filenames.map do |file|
        path = file_path(file)
        raise "No file found for reference #{file}" if path.nil?
        { 'name' => file, 'path' => path }
      end

      unless dirnames.empty?
        files.each do |file|
          name = file['name']
          if dirnames.any? { |dirname| name.start_with?(dirname) }
            impl['files'] << { 'name' => name, 'path' => file_path(name) }
          end
        end
      end

      impl
    end

    def eql?(other)
      self.class == other.class &&
        @name == other.name &&
        @metadata == other.metadata &&
        @files == other.files &&
        @remote == other.remote
    end

    alias == :eql?

    def to_h
      {
        name: @name,
        files: @files,
        metadata: @metadata
      }
    end

    def validate_metadata
      unknown_keys = metadata.keys - METADATA_KEYS

      if unknown_keys.any?
        msg = "Metadata for task '#{@name}' contains unknown keys: #{unknown_keys.join(', ')}."
        msg += " This could be a typo in the task metadata or may result in incorrect behavior."
        Bolt::Logger.warn("unknown_task_metadata_keys", msg)
      end
    end
  end
end
