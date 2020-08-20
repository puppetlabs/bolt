# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/puppetdb'
require 'bolt/catalog'
require 'bolt/task'

describe "passes parsed AST to the apply_catalog task" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::PuppetDB

  let(:modulepath) { File.join(__dir__, '../fixtures/apply') }
  let(:trusted_external) { File.join(__dir__, '../fixtures/scripts/trusted_external_facts.sh') }
  let(:config_flags) { %W[--format json --targets #{uri} --password #{password} --modulepath #{modulepath}] + tflags }

  before(:each) do
    allow(Bolt::ApplyResult).to receive(:from_task_result) { |r| r }
    # Don't print warnings
    allow($stdout).to receive(:puts)
    allow_any_instance_of(Bolt::Applicator).to receive(:catalog_apply_task) {
      path = File.join(__dir__, "../fixtures/apply/#{apply_task}")
      impl = { 'name' => apply_task, 'path' => path }
      metadata = { 'supports_noop' => true, 'input_method' => 'environment' }
      Bolt::Task.new('apply_catalog', metadata, [impl])
    }
  end

  def get_notifies(result)
    expect(result).not_to include('kind')
    expect(result[0]).to include('status' => 'success')
    result[0]['value']['report']['catalog']['resources'].select { |r| r['type'] == 'Notify' }
  end

  # SSH only required to simplify capturing stdin passed to the task. WinRM omitted as slower and unnecessary.
  describe 'over ssh', ssh: true do
    let(:uri) { conn_uri('ssh') }
    let(:password) { conn_info('ssh')[:password] }
    let(:apply_task) { 'apply_catalog.sh' }
    let(:tflags) { %w[--no-host-key-check] }

    it 'the catalog include the expected resources' do
      result = run_cli_json(%w[plan run basic] + config_flags)
      reports = result[0]
      expect(reports.count).to eq(5)

      resources = reports.group_by { |r| r['type'] }
      expect(resources['File'].count).to eq(2)
      files = resources['File'].select { |f| f['title'] == '/root/test/hello.txt' }
      expect(files.count).to eq(1)
      expect(files[0]['parameters']['content']).to match(/hi there I'm Debian/)
    end

    it 'uses trusted facts' do
      result = run_cli_json(%w[plan run basic::trusted] + config_flags)
      notify = get_notifies(result)
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq(
        "trusted {authenticated => local, certname => #{uri}, extensions => {}, "\
        "hostname => #{uri}, domain => , external => {}}"
      )
    end

    it 'uses trusted external facts' do
      with_tempfile_containing('bolt', YAML.dump("trusted-external-command" => trusted_external), '.yaml') do |conf|
        result = run_cli_json(%W[plan run basic::trusted --configfile #{conf.path}] + config_flags)
        notify = get_notifies(result)
        expect(notify.count).to eq(1)
        expect(notify[0]['title']).to eq(
          "trusted {authenticated => local, certname => #{uri}, extensions => {}, "\
          "hostname => #{uri}, domain => , external => {hot => cocoa, pepper => mint}}"
        )
      end
    end

    it 'errors if trusted external facts path does not exist' do
      with_tempfile_containing('bolt', YAML.dump("trusted-external-command" => '/absent.sh'), '.yaml') do |conf|
        expect { run_cli_json(%W[plan run basic::trusted --configfile #{conf.path}] + config_flags) }
          .to raise_error(Bolt::FileError, %r{The trusted-external-command '/absent.sh' does not exist})
      end
    end

    it 'uses target vars' do
      result = run_cli_json(%w[plan run basic::target_vars] + config_flags)
      notify = get_notifies(result)
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq('hello there')
    end

    it 'plan vars override target vars and respects variables explicitly set to undef' do
      result = run_cli_json(%w[plan run basic::plan_vars] + config_flags)
      notify = get_notifies(result)
      expect(notify.count).to eq(1)
      expect(notify[0]['title']).to eq('hello world')
      logs = @log_output.readlines
      expect(logs).not_to include(/Unknown variable: 'signature'/)
      expect(logs).not_to include(/Unknown variable: 'plan_undef'/)
      expect(logs).to include(/Unknown variable: 'apply_undef'/)
      expect(logs).to include(/Plan vars set to undef:/)
    end

    it 'facts override plan vars and target vars' do
      result = run_cli_json(%w[plan run basic::fact_merge] + config_flags)
      notify = get_notifies(result)
      expect(notify[0]['title']).to eq('Fresh strawberries')
      logs = @log_output.readlines
      expect(logs).to include(/Plan variable \$fresh will be overridden by fact/)
      expect(logs).to include(/Target variable \$fresh will be overridden by fact/)
    end

    it 'applies a class from the modulepath' do
      result = run_cli_json(%w[plan run basic::class] + config_flags)
      notify = get_notifies(result)
      expect(notify.count).to eq(1)
    end

    it 'allows and warns on language violations (strict=warning)' do
      result = run_cli_json(%w[plan run basic::strict] + config_flags)
      notify = get_notifies(result)
      expect(notify.count).to eq(1)
      expect(notify[0]['parameters']['message']).to eq('a' => 2)
      logs = @log_output.readlines
      expect(logs).to include(/WARN.*The key 'a' is declared more than once/)
    end

    it 'allows undefined variables (strict_variables=false)' do
      result = run_cli_json(%w[plan run basic::strict_variables] + config_flags)
      notify = get_notifies(result)
      expect(notify.count).to eq(1)
      expect(notify[0]['parameters']['message']).to eq('hello ')
    end

    it 'applies a complex type from the modulepath' do
      result = run_cli_json(%w[plan run basic::type] + config_flags)
      report = result[0]['value']['report']
      warn = report['catalog']['resources'].select { |r| r['type'] == 'Warn' }
      expect(warn.count).to eq(1)
    end

    it 'evaluates a node definition matching the node name' do
      result = run_cli_json(%w[plan run basic::node_definition] + config_flags)
      report = result[0]['value']['report']
      warn = report['catalog']['resources'].select { |r| r['type'] == 'Warn' }
      expect(warn.count).to eq(1)
    end

    it 'evaluates a default node definition if none matches the node name' do
      result = run_cli_json(%w[plan run basic::node_default] + config_flags)
      report = result[0]['value']['report']
      warn = report['catalog']['resources'].select { |r| r['type'] == 'Warn' }
      expect(warn.count).to eq(1)
    end

    it 'logs messages emitted during compilation' do
      result = run_cli_json(%w[plan run basic::error] + config_flags)
      expect(result[0]['status']).to eq('success')
      logs = @log_output.readlines
      expect(logs).to include(/TRACE.*Debugging/)
      expect(logs).to include(/DEBUG.*Meh/)
      expect(logs).to include(/WARN.*Warned/)
      expect(logs).to include(/INFO.*Helpful/)
      expect(logs).to include(/ERROR.*Fire/)
      expect(logs).to include(/ERROR.*Stop/)
      expect(logs).to include(/FATAL.*Drop/)
      expect(logs).to include(/FATAL.*Roll/)
    end

    it 'fails immediately on a compile error' do
      result = run_cli_json(%w[plan run basic::catch_error catch=false] + config_flags)
      expect(result['kind']).to eq('bolt/apply-failure')
      error = result['details']['result_set'][0]['value']['_error']
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
      expect(@log_output.readlines)
        .to include(/stop the insanity/)
    end

    it 'returns a ResultSet containing failure with _catch_errors=true' do
      result = run_cli_json(%w[plan run basic::catch_error catch=true] + config_flags)
      expect(result['kind']).to eq('bolt/apply-error')
      expect(result['msg']).to match(/Apply failed to compile for #{uri}/)
      expect(@log_output.readlines)
        .to include(/stop the insanity/)
    end

    it 'errors calling run_task' do
      result = run_cli_json(%w[plan run basic::disabled] + config_flags)
      expect(result['kind']).to eq('bolt/apply-failure')
      error = result['details']['result_set'][0]['value']['_error']
      expect(error['kind']).to eq('bolt/apply-error')
      expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
      expect(@log_output.readlines)
        .to include(/Plan language function 'run_task' cannot be used from declarative manifest code/)
    end

    context 'with puppetdb misconfigured' do
      let(:pdb_conf) {
        {
          'server_urls' => 'https://puppetdb.example.com',
          'cacert' => '/path/to/cacert'
        }
      }

      let(:config) { {} }

      it 'calls puppetdb_query' do
        result = run_cli_json(%w[plan run basic::pdb_query] + config_flags)
        expect(result['kind']).to eq('bolt/apply-failure')
        error = result['details']['result_set'][0]['value']['_error']
        expect(error['kind']).to eq('bolt/apply-error')
        expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
        expect(@log_output.readlines).to include(/Failed to connect to all PuppetDB server_urls/)
      end

      it 'calls puppetdb_fact' do
        result = run_cli_json(%w[plan run basic::pdb_fact] + config_flags)
        expect(result['kind']).to eq('bolt/apply-failure')
        error = result['details']['result_set'][0]['value']['_error']
        expect(error['kind']).to eq('bolt/apply-error')
        expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
        expect(@log_output.readlines).to include(/Failed to connect to all PuppetDB server_urls/)
      end
    end

    context 'with hiera config stubbed' do
      let(:default_datadir) {
        {
          'hiera-config' => File.join(__dir__, '../fixtures/apply/hiera.yaml').to_s
        }
      }
      let(:custom_datadir) {
        {
          'hiera-config' => File.join(__dir__, '../fixtures/apply/hiera_datadir.yaml').to_s
        }
      }
      let(:bad_hiera_version) {
        {
          'hiera-config' => File.join(__dir__, '../fixtures/apply/hiera_invalid.yaml').to_s
        }
      }
      let(:eyaml_config) {
        {
          "version" => 5,
          "defaults" => { "data_hash" => "yaml_data", "datadir" => File.join(__dir__, '../fixtures/apply/data').to_s },
          "hierarchy" => [{
            "name" => "Encrypted Data",
            "lookup_key" => "eyaml_lookup_key",
            "paths" => ["secure.eyaml"],
            "options" => {
              "pkcs7_private_key" => File.join(__dir__, '../fixtures/keys/private_key.pkcs7.pem').to_s,
              "pkcs7_public_key" => File.join(__dir__, '../fixtures/keys/public_key.pkcs7.pem').to_s
            }
          }]
        }
      }

      it 'default datadir is accessible' do
        with_tempfile_containing('conf', YAML.dump(default_datadir)) do |conf|
          result = run_cli_json(%W[plan run basic::hiera_lookup --configfile #{conf.path}] + config_flags)
          notify = get_notifies(result)
          expect(notify[0]['title']).to eq("hello default datadir")
        end
      end

      it 'non-default datadir specified in hiera config is accessible' do
        with_tempfile_containing('conf', YAML.dump(custom_datadir)) do |conf|
          result = run_cli_json(%W[plan run basic::hiera_lookup --configfile #{conf.path}] + config_flags)
          notify = get_notifies(result)
          expect(notify[0]['title']).to eq("hello custom datadir")
        end
      end

      it 'hiera eyaml can be decoded' do
        with_tempfile_containing('yaml', YAML.dump(eyaml_config)) do |yaml_data|
          config = { 'hiera-config' => yaml_data.path.to_s }
          with_tempfile_containing('conf', YAML.dump(config)) do |conf|
            result = run_cli_json(%W[plan run basic::hiera_lookup --configfile #{conf.path}] + config_flags)
            notify = get_notifies(result)
            expect(notify[0]['title']).to eq("hello encrypted value")
          end
        end
      end

      it 'hiera 5 version not specified' do
        with_tempfile_containing('conf', YAML.dump(bad_hiera_version)) do |conf|
          result = run_cli_json(%W[plan run basic::hiera_lookup --configfile #{conf.path}] + config_flags)
          expect(result['kind']).to eq('bolt/parse-error')
          expect(result['msg']).to match(/Hiera v5 is required, found v3/)
        end
      end
    end

    context 'when using project-level content' do
      let(:project) { File.join(__dir__, '../fixtures/projects/named') }

      it 'applies a class contained in a project-level manifest' do
        result = run_cli_json(%W[plan run test_project::apply --boltdir #{project}] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq('project notify')
      end
    end

    context 'with inventoryfile stubbed' do
      let(:inventory) {
        {
          'inventoryfile' => File.join(__dir__, '../fixtures/apply/inventory.yaml').to_s
        }
      }

      it 'vars cannot be set on the target' do
        with_tempfile_containing('conf', YAML.dump(inventory)) do |conf|
          result = run_cli_json(%W[plan run basic::xfail_set_var --configfile #{conf.path}] + config_flags)
          expect(result['kind']).to eq('bolt/apply-failure')
          expect(result['msg']).to match(/Apply failed to compile for/)
        end
      end

      it 'features cannot be set on the target' do
        with_tempfile_containing('conf', YAML.dump(inventory)) do |conf|
          result = run_cli_json(%W[plan run basic::xfail_set_feature --configfile #{conf.path}] + config_flags)
          expect(result['kind']).to eq('bolt/apply-failure')
          expect(result['msg']).to match(/Apply failed to compile for/)
        end
      end
    end

    context 'with Bolt plan datatypes' do
      let(:inventory) { File.join(__dir__, '../fixtures/apply/inventory.yaml') }
      let(:tflags) { %W[--no-host-key-check --inventoryfile #{inventory} --run-as root] }

      it 'serializes ResultSet objects in apply blocks' do
        result = run_cli_json(%w[plan run puppet_types::resultset] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq("ResultSet target names: [ssh://bolt@localhost:20022]")
      end

      it 'serializes Result objects in apply blocks' do
        result = run_cli_json(%w[plan run puppet_types::result] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq("Result value: root\n")
        expect(notify[1]['title']).to eq("Result target name: ssh://bolt@localhost:20022")
      end

      it 'serializes ApplyResult objects in apply blocks' do
        result = run_cli_json(%w[plan run puppet_types::applyresult] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq("ApplyResult resource: /home/bolt/tmp")
      end

      it 'serializes Target objects as ApplyTargets in apply blocks' do
        result = run_cli_json(%w[plan run puppet_types::target] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq("ApplyTarget ssh://bolt@localhost:20022 protocol: ssh")
      end

      it 'serializes Error objects in apply blocks' do
        result = run_cli_json(%w[plan run puppet_types::error] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq("ApplyResult resource: The command failed with exit code 127")
      end

      it 'preserves the sensitive data of Results' do
        result = run_cli_json(%w[plan run puppet_types::sensitive_result] + config_flags)
        notify = get_notifies(result)
        expect(notify[0]['title']).to eq("Result sensitive value: secretpassword")
      end

      context 'when calling invalid functions in apply' do
        it 'errors when get_targets is called' do
          result = run_cli_json(%w[plan run puppet_types::get_targets] + config_flags)
          expect(result['kind']).to eq('bolt/apply-failure')
          error = result['details']['result_set'][0]['value']['_error']
          expect(error['kind']).to eq('bolt/apply-error')
          expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
          expect(@log_output.readlines)
            .to include(/The function 'get_targets' is not callable within an apply block/)
        end

        it 'errors when get_target is called' do
          result = run_cli_json(%w[plan run puppet_types::get_target] + config_flags)
          expect(result['kind']).to eq('bolt/apply-failure')
          error = result['details']['result_set'][0]['value']['_error']
          expect(error['kind']).to eq('bolt/apply-error')
          expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
          expect(@log_output.readlines)
            .to include(/The function 'get_target' is not callable within an apply block/)
        end

        it 'errors when Target.new is called' do
          result = run_cli_json(%w[plan run puppet_types::target_new] + config_flags)
          expect(result['kind']).to eq('bolt/apply-failure')
          error = result['details']['result_set'][0]['value']['_error']
          expect(error['kind']).to eq('bolt/apply-error')
          expect(error['msg']).to match(/Apply failed to compile for #{uri}/)
          expect(@log_output.readlines)
            .to include(/Target objects cannot be instantiated inside apply blocks/)
        end
      end
    end

    context 'setting log level' do
      let(:lines) { @log_output.readlines }

      after(:each) { @log_output.level = :all }

      it 'logs debug messages' do
        @log_output.level = :debug
        run_cli(%w[plan run basic::error --log-level debug] + config_flags)

        expect(lines).not_to include(/TRACE.*Debugging/)
        expect(lines).to include(/DEBUG.*Meh/)
        expect(lines).to include(/INFO.*Helpful/)
        expect(lines).to include(/WARN.*Warned/)
        expect(lines).to include(/ERROR.*Fire/)
        expect(lines).to include(/ERROR.*Stop/)
        expect(lines).to include(/FATAL.*Drop/)
        expect(lines).to include(/FATAL.*Roll/)
      end

      it 'logs info messages' do
        @log_output.level = :info
        run_cli(%w[plan run basic::error --log-level info] + config_flags)

        expect(lines).not_to include(/TRACE.*Debugging/)
        expect(lines).not_to include(/DEBUG.*Meh/)
        expect(lines).to include(/INFO.*Helpful/)
        expect(lines).to include(/WARN.*Warned/)
        expect(lines).to include(/ERROR.*Fire/)
        expect(lines).to include(/ERROR.*Stop/)
        expect(lines).to include(/FATAL.*Drop/)
        expect(lines).to include(/FATAL.*Roll/)
      end

      it 'logs warn messages' do
        @log_output.level = :warn
        run_cli(%w[plan run basic::error --log-level warn] + config_flags)

        expect(lines).not_to include(/TRACE.*Debugging/)
        expect(lines).not_to include(/DEBUG.*Meh/)
        expect(lines).not_to include(/INFO.*Helpful/)
        expect(lines).to include(/WARN.*Warned/)
        expect(lines).to include(/ERROR.*Fire/)
        expect(lines).to include(/ERROR.*Stop/)
        expect(lines).to include(/FATAL.*Drop/)
        expect(lines).to include(/FATAL.*Roll/)
      end

      it 'logs error messages' do
        @log_output.level = :error
        run_cli(%w[plan run basic::error --log-level error] + config_flags)

        expect(lines).not_to include(/TRACE.*Debugging/)
        expect(lines).not_to include(/DEBUG.*Meh/)
        expect(lines).not_to include(/INFO.*Helpful/)
        expect(lines).not_to include(/WARN.*Warned/)
        expect(lines).to include(/ERROR.*Fire/)
        expect(lines).to include(/ERROR.*Stop/)
        expect(lines).to include(/FATAL.*Drop/)
        expect(lines).to include(/FATAL.*Roll/)
      end

      it 'logs fatal messages' do
        @log_output.level = :fatal
        run_cli(%w[plan run basic::error --log-level fatal] + config_flags)

        expect(lines).not_to include(/TRACE.*Debugging/)
        expect(lines).not_to include(/DEBUG.*Meh/)
        expect(lines).not_to include(/INFO.*Helpful/)
        expect(lines).not_to include(/WARN.*Warned/)
        expect(lines).not_to include(/ERROR.*Fire/)
        expect(lines).not_to include(/ERROR.*Stop/)
        expect(lines).to include(/FATAL.*Drop/)
        expect(lines).to include(/FATAL.*Roll/)
      end
    end
  end
end
