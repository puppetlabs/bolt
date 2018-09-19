# frozen_string_literal: true

module Bolt
  # Represents a Task.
  # @file and @files are mutually exclusive.
  # @name [String] name of the task
  # @file [Hash, nil] containing `filename` and `file_content`
  # @files [Array<Hash>] where each entry includes `name` and `path`
  # @metadata [Hash] task metadata
  Task = Struct.new(
    :name,
    :file,
    :files,
    :metadata
  ) do

    def initialize(task)
      super(nil, nil, [], {})

      task.reject { |k, _| k == 'parameters' }.each { |k, v| self[k] = v }
    end

    def description
      metadata['description']
    end

    def parameters
      metadata['parameters']
    end

    def supports_noop
      metadata['supports_noop']
    end

    def file_map
      @file_map ||= files.each_with_object({}) { |file, hsh| hsh[file['name']] = file['path'] }
    end
    private :file_map

    # Returns a hash of implementation name, path to executable, input method (if defined),
    # and any additional files (name and path)
    def select_implementation(target, additional_features = [])
      raise 'select_implementation only supported with multiple files' if files.nil? || files.empty?

      impl = if (impls = metadata['implementations'])
               available_features = target.features + additional_features
               impl = impls.find { |imp| Set.new(imp['requirements']).subset?(available_features) }
               raise "No suitable implementation of #{name} for #{target.name}" unless impl
               impl = impl.dup
               impl['path'] = file_map[impl['name']]
               impl.delete('requirements')
               impl
             else
               files.first.dup
             end

      unless (inmethod = metadata['input_method']).nil?
        impl['input_method'] = inmethod
      end
      impl
    end
  end
end
