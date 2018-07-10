# frozen_string_literal: true

require 'json'
require 'open3'

module Bolt
  Task = Struct.new(:name, :implementations, :input_method)

  class Applicator
    def initialize(inventory, executor)
      @inventory = inventory
      @executor = executor
    end

    private def libexec
      @libexec ||= File.join(Gem::Specification.find_by_name('bolt').gem_dir, 'libexec')
    end

    def catalog_apply_task
      path = File.join(libexec, 'apply_catalog.rb')
      impl = { 'name' => 'apply_catalog.rb', 'path' => path, 'requirements' => [], 'supports_noop' => true }
      Task.new('apply_catalog', [impl], 'stdin')
    end

    def compile(target, ast)
      catalog_input = {
        code_ast: ast,
        modulepath: [],
        target: {
          name: target.host,
          facts: @inventory.facts(target),
          variables: @inventory.vars(target)
        }
      }

      bolt_catalog_exe = File.join(libexec, 'bolt_catalog')

      old_path = ENV['PATH']
      ENV['PATH'] = "#{RbConfig::CONFIG['bindir']}#{File::PATH_SEPARATOR}#{old_path}"
      out, err, stat = Open3.capture3('ruby', bolt_catalog_exe, 'compile', stdin_data: catalog_input.to_json)
      ENV['PATH'] = old_path

      raise ApplyError.new(target.to_s, err) unless stat.success?
      JSON.parse(out)
    end

    def apply(args, apply_body, _scope)
      raise(ArgumentError, 'apply requires a TargetSpec') if args.empty?
      type0 = Puppet.lookup(:pal_script_compiler).type('TargetSpec')
      Puppet::Pal.assert_type(type0, args[0], 'apply targets')

      params = {}
      if args.count > 1
        type1 = Puppet.lookup(:pal_script_compiler).type('Hash[String, Data]')
        Puppet::Pal.assert_type(type1, args[1], 'apply options')
        params = args[1]
      end

      targets = @inventory.get_targets(args[0])
      ast = Puppet::Pops::Serialization::ToDataConverter.convert(apply_body, rich_data: true, symbol_to_string: true)
      results = targets.map do |target|
        params['catalog'] = compile(target, ast)
        @executor.run_task([target], catalog_apply_task, params, '_description' => 'apply catalog')
      end
      ResultSet.new results.reduce([]) { |result, result_set| result + result_set.results }
    end
  end
end
