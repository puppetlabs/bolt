# frozen_string_literal: true

require 'bolt/bolt_option_parser'
require 'bolt/inventory' # Needed for Bolt::Inventory::ENVIRONMENT_VAR
require 'bolt_spec/files'
require 'bolt_spec/env_var'

describe 'parser' do
  include BoltSpec::EnvVar
  include BoltSpec::Files

  let(:options) { {} }
  let(:parser)  { Bolt::BoltOptionParser.new(options) }

  describe '#permute' do
    it 'errors with a missing option parameter' do
      expect {
        parser.permute(%w[--targets])
      }.to raise_error(Bolt::CLIError, /Option '--targets' needs a parameter/)
    end

    it 'errors with an invalid option parameter' do
      expect {
        parser.permute(%w[--connect-timeout none])
      }.to raise_error(Bolt::CLIError, /Invalid parameter specified for option '--connect-timeout'/)
    end

    it 'errors with an unknown option' do
      expect {
        parser.permute(%w[--explode])
      }.to raise_error(Bolt::CLIError, /Unknown argument '--explode'/)
    end

    describe '--env-vars' do
      it 'parses environment variables' do
        parser.permute(%w[--env-var FOO=bar])
        expect(options[:env_vars]).to include(
          'FOO' => 'bar'
        )
      end
    end

    describe '--filter' do
      it 'errors with an invalid filter' do
        expect { parser.permute(%w[--filter JSON]) }.to raise_error(
          Bolt::CLIError,
          /Illegal characters in filter string 'JSON'/
        )
      end
    end

    describe '--inventoryfile' do
      it 'expands path relative to current directory' do
        parser.permute(%w[--inventoryfile inventory.yaml])
        expect(options[:inventoryfile]).to eq(File.expand_path('inventory.yaml', Dir.pwd))
      end

      it 'errors if BOLT_INVENTORY is set' do
        with_env_vars('BOLT_INVENTORY' => '{}') do
          expect { parser.permute(%w[--inventoryfile inventory.yaml]) }.to raise_error(
            Bolt::CLIError,
            /Cannot pass inventory file when BOLT_INVENTORY is set/
          )
        end
      end
    end

    describe '--modulepath' do
      it 'expands path relative to current directory' do
        parser.permute(%w[--modulepath modules])
        expect(options[:modulepath]).to match_array(
          [File.expand_path('modules', Dir.pwd)]
        )
      end

      it 'splits paths by path separator' do
        parser.permute(%W[--modulepath modules#{File::PATH_SEPARATOR}site])
        expect(options[:modulepath]).to match_array(
          [File.expand_path('modules', Dir.pwd), File.expand_path('site', Dir.pwd)]
        )
      end
    end

    describe '--modules' do
      it 'accepts a single module' do
        parser.permute(%w[--modules puppetlabs-apt])
        expect(options[:modules]).to match_array(
          [{ 'name' => 'puppetlabs-apt' }]
        )
      end

      it 'accepts multiple modules' do
        parser.permute(%w[--modules puppetlabs-apt,puppetlabs-yum])
        expect(options[:modules]).to match_array(
          [{ 'name' => 'puppetlabs-apt' }, { 'name' => 'puppetlabs-yum' }]
        )
      end
    end

    describe '--params' do
      let(:params) { '{"foo":"bar","baz":"bak"}' }

      it 'parses JSON as parameters' do
        parser.permute(%W[--params #{params}])
        expect(options[:params]).to eq(JSON.parse(params))
      end

      it 'reads parameters from stdin' do
        allow($stdin).to receive(:read).and_return(params)
        parser.permute(%w[--params -])
        expect(options[:params]).to eq(JSON.parse(params))
      end

      it 'reads parameters from a file' do
        with_tempfile_containing('params', params) do |file|
          parser.permute(%W[--params @#{file.path}])
          expect(options[:params]).to eq(JSON.parse(params))
        end
      end

      it 'errors if the params file does not exist' do
        Dir.mktmpdir(nil, Dir.pwd) do |dir|
          expect { parser.permute(%W[--params @#{dir}/nope]) }.to raise_error(
            Bolt::FileError,
            /No such file/
          )
        end
      end

      it 'errors if unable to parse as JSON' do
        expect { parser.permute(%w[--params {"foo"=>"bar"}]) }.to raise_error(
          Bolt::CLIError,
          /Unable to parse --params value as JSON/
        )
      end
    end

    describe '--password-prompt' do
      it 'prompts for a password' do
        allow($stdin).to receive(:noecho).and_return('opensesame')
        allow($stderr).to receive(:print).with('Please enter your password: ')
        allow($stderr).to receive(:puts)
        parser.permute(%w[--password-prompt])
        expect(options[:password]).to eq('opensesame')
      end
    end

    describe '--private-key' do
      let(:path) { './ssh/google_compute_engine' }

      it "expands private key relative to current directory" do
        allow(Bolt::Util).to receive(:validate_file).and_return(true)
        parser.permute(%W[--private-key #{path}])
        expect(options[:'private-key']).to eq(File.expand_path(path, Dir.pwd))
      end
    end

    describe '--script' do
      it 'errors with a relative path' do
        # This path is specifically structured so that it *won't* be caught by
        # verifying `scripts` is the second segment of the path.
        expect { parser.permute(%w[--script ./scripts/ci.ps1]) }
          .to raise_error(Bolt::CLIError, /The script must be a detailed Puppet file ref/)
      end

      it 'errors with an absolute path' do
        path = File.expand_path('./scripts/ci.ps1')
        expect { parser.permute(%W[--script #{path}]) }
          .to raise_error(Bolt::CLIError, /The script must be a detailed Puppet file ref/)
      end

      it 'errors with a nonspecific Puppet file reference' do
        expect { parser.permute(%w[--script mymodule/myfile]) }
          .to raise_error(Bolt::CLIError, /The script must be a detailed Puppet file ref/)
      end

      it 'accepts a Puppet file reference to the scripts directory' do
        parser.permute(%w[--script mymodule/scripts/myscript.sh])
        expect(options[:plan_script]).to eq('mymodule/scripts/myscript.sh')
      end
    end

    describe '--sudo-password-prompt' do
      it 'prompts for a password' do
        allow($stdin).to receive(:noecho).and_return('opensesame')
        allow($stderr).to receive(:print).with('Please enter your privilege escalation password: ')
        allow($stderr).to receive(:puts)
        parser.permute(%w[--sudo-password-prompt])
        expect(options[:'sudo-password']).to eq('opensesame')
      end
    end

    describe '--targets' do
      it 'accepts a single target' do
        parser.permute(%w[--targets foo])
        expect(options[:targets]).to match_array(%w[foo])
      end

      it 'accepts multiple targets' do
        parser.permute(%w[--targets foo,bar])
        expect(options[:targets]).to match_array(%w[foo,bar])
      end

      it 'accepts multiple targets across multiple declarations' do
        parser.permute(%w[--targets foo --targets bar])
        expect(options[:targets]).to match_array(%w[foo bar])
      end

      it 'reads targets from stdin' do
        expect($stdin).to receive(:read).and_return('foo')
        parser.permute(%w[--targets -])
        expect(options[:targets]).to match_array(%w[foo])
      end

      it 'reads targets from a file' do
        with_tempfile_containing('targets', "foo\nbar\n") do |file|
          parser.permute(%W[--targets @#{file.path}])
          expect(options[:targets]).to match_array(["foo\nbar\n"])
        end
      end
    end

    describe '--transport' do
      it 'errors with an invalid transport' do
        expect { parser.permute(%w[--transport subaru]) }.to raise_error(
          Bolt::CLIError,
          /Invalid parameter specified for option '--transport': subaru/
        )
      end
    end
  end

  describe '#get_help_text' do
    it 'returns help for apply' do
      result = parser.get_help_text('apply')
      expect(result[:flags]).to include('noop')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for command run' do
      result = parser.get_help_text('command', 'run')
      expect(result[:flags]).to include('env-var')
    end

    it 'returns help for command (no action)' do
      result = parser.get_help_text('command')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for file upload' do
      result = parser.get_help_text('file', 'upload')
      expect(result[:flags]).to include('tmpdir')
    end

    it 'returns help for file download' do
      result = parser.get_help_text('file', 'download')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for file (no action)' do
      result = parser.get_help_text('file')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for inventory show' do
      result = parser.get_help_text('inventory', 'show')
      expect(result[:flags]).to include('detail')
    end

    it 'returns help for inventory (no action)' do
      result = parser.get_help_text('inventory')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for group show' do
      result = parser.get_help_text('group', 'show')
      expect(result[:flags]).to include('inventoryfile')
    end

    it 'returns help for group (no action)' do
      result = parser.get_help_text('group')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for guide' do
      result = parser.get_help_text('guide')
      expect(result[:flags]).to include('format')
    end

    it 'returns help for lookup' do
      result = parser.get_help_text('lookup')
      expect(result[:flags]).to include('hiera-config')
    end

    it 'returns help for module add' do
      result = parser.get_help_text('module', 'add')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for module generate-types' do
      result = parser.get_help_text('module', 'generate-types')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for module install' do
      result = parser.get_help_text('module', 'install')
      expect(result[:flags]).to include('force')
    end

    it 'returns help for module show' do
      result = parser.get_help_text('module', 'show')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for module (no action)' do
      result = parser.get_help_text('module')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for plan convert' do
      result = parser.get_help_text('plan', 'convert')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for plan new' do
      result = parser.get_help_text('plan', 'new')
      expect(result[:flags]).to include('pp')
    end

    it 'returns help for plan run' do
      result = parser.get_help_text('plan', 'run')
      expect(result[:flags]).to include('params')
    end

    it 'returns help for plan show' do
      result = parser.get_help_text('plan', 'show')
      expect(result[:flags]).to include('filter')
    end

    it 'returns help for plan (no action)' do
      result = parser.get_help_text('plan')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for plugin show' do
      result = parser.get_help_text('plugin', 'show')
      expect(result[:flags]).to include('modulepath')
    end

    it 'returns help for plugin (no action)' do
      result = parser.get_help_text('plugin')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for policy apply' do
      result = parser.get_help_text('policy', 'apply')
      expect(result[:flags]).to include('noop')
    end

    it 'returns help for policy new' do
      result = parser.get_help_text('policy', 'new')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for policy show' do
      result = parser.get_help_text('policy', 'show')
      expect(result[:banner]).to be_a(String)
    end

    it 'returns help for policy (no action)' do
      result = parser.get_help_text('policy')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for project init' do
      result = parser.get_help_text('project', 'init')
      expect(result[:flags]).to include('modules')
    end

    it 'returns help for project migrate' do
      result = parser.get_help_text('project', 'migrate')
      expect(result[:flags]).to include('inventoryfile')
    end

    it 'returns help for project (no action)' do
      result = parser.get_help_text('project')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for script run' do
      result = parser.get_help_text('script', 'run')
      expect(result[:flags]).to include('env-var')
    end

    it 'returns help for script (no action)' do
      result = parser.get_help_text('script')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for secret createkeys' do
      result = parser.get_help_text('secret', 'createkeys')
      expect(result[:flags]).to include('force')
    end

    it 'returns help for secret decrypt' do
      result = parser.get_help_text('secret', 'decrypt')
      expect(result[:flags]).to include('plugin')
    end

    it 'returns help for secret encrypt' do
      result = parser.get_help_text('secret', 'encrypt')
      expect(result[:flags]).to include('plugin')
    end

    it 'returns help for secret (no action)' do
      result = parser.get_help_text('secret')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns help for task run' do
      result = parser.get_help_text('task', 'run')
      expect(result[:flags]).to include('noop')
    end

    it 'returns help for task show' do
      result = parser.get_help_text('task', 'show')
      expect(result[:flags]).to include('filter')
    end

    it 'returns help for task (no action)' do
      result = parser.get_help_text('task')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end

    it 'returns top-level banner for unknown subcommand' do
      result = parser.get_help_text('unknown')
      expect(result[:flags]).to eq(Bolt::BoltOptionParser::OPTIONS[:global])
    end
  end
end
