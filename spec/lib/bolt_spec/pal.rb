# frozen_string_literal: true

require 'bolt_spec/files'
require 'bolt/config'
require 'bolt/pal'

module BoltSpec
  module PAL
    include BoltSpec::Files

    def config
      conf = Bolt::Config.new
      conf[:modulepath] = modulepath
      conf
    end

    def modulepath
      [File.join(__FILE__, '..', '..', '..', 'fixtures', 'modules')]
    end

    def peval(code, pal, executor = nil, inventory = nil, pdb_client = nil)
      pal.in_plan_compiler(executor, inventory, pdb_client) do |c|
        c.evaluate_string(code)
      end
    end

    def mk_files(path, content)
      FileUtils.mkdir_p(path)
      content.each do |name, cont|
        full_path = File.join(path, name)
        if cont.is_a? Hash
          mk_files(full_path, cont)
        else
          File.open(full_path, 'w') { |f| f.write(cont) }
        end
      end
    end

    def pal_with_module_content(mods)
      Dir.mktmpdir do |tmpdir|
        mk_files(tmpdir, mods)
        pal = Bolt::PAL.new(tmpdir, nil, nil)
        yield pal
      end
    end
  end
end
