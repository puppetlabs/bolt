module BoltSpec
  module PAL
    include BoltSpec::Files

    def modulepath
      [File.join(__FILE__, '..', '..', '..', 'fixtures', 'modules')]
    end

    def config
      conf = Bolt::Config.new
      conf[:modulepath] = modulepath
      conf[:log_level] = :notice
      conf
    end

    def peval(code, pal)
      pal.in_bolt_compiler do |c|
        c.evaluate_string(code)
      end
    end

    def with_manifest(_code, _name, _type, _moduledir)
      # TODO: write code to a tempdir on the module path
      q_name = 'dne'
      yield q_name
    end
  end
end
