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
end
