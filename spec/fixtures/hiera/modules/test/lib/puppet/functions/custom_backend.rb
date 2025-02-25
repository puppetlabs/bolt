# frozen_string_literal: true

Puppet::Functions.create_function(:custom_backend) do
  dispatch :custom_backend do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  argument_mismatch :missing_path do
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def custom_backend(options, context)
    path = options['path']
    context.cached_file_data(path) do |content|
      data = content.split("\n").each_with_object({}) do |line, acc|
        key, value = line.strip.split('=')
        acc[key] = value
      end

      if data.is_a?(Hash)
        Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data)
      else
        msg = _(format("%<path>s: file does not contain valid data", path: path))
        raise Puppet::DataBinding::LookupError, msg if Puppet[:strict] == :error && data != false
        Puppet.warning(msg)
        {}
      end
    end
  end

  def missing_path(_options, _context)
    "one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when " \
      "using this data_hash function"
  end
end
