# frozen_string_literal: true

require 'spec_helper'
require 'bolt/analytics'

describe Bolt::Analytics do
  let(:default_config) { {} }

  before :each do
    # We use a hard override to disable analytics for tests, but that obviously
    # interferes with these tests...
    ENV.delete('BOLT_DISABLE_ANALYTICS')

    # Ensure these tests will never read or write a local config
    allow(subject).to receive(:load_config).and_return(default_config)
    allow(subject).to receive(:write_config)
  end

  it 'creates a NoopClient if analytics is disabled' do
    default_config.replace('disabled' => true)
    expect(subject).not_to receive(:write_config)

    expect(subject.build_client).to be_instance_of(Bolt::Analytics::NoopClient)
  end

  it 'creates a NoopClient if reading config fails' do
    allow(File).to receive(:expand_path).and_call_original
    allow(File)
      .to receive(:expand_path)
      .with('~/.puppetlabs/bolt/analytics.yaml')
      .and_raise(ArgumentError, "couldn't find login name -- expanding `~'")
    expect(subject).not_to receive(:write_config)

    expect(subject.build_client).to be_instance_of(Bolt::Analytics::NoopClient)
  end

  it 'creates a regular Client if analytics is not disabled' do
    expect(subject.build_client).to be_instance_of(Bolt::Analytics::Client)
  end

  it 'uses the uuid in the config if it exists' do
    uuid = SecureRandom.uuid
    default_config.replace('user-id' => uuid)

    expect(subject.build_client.user_id).to eq(uuid)
  end

  it "assigns the user a uuid if one doesn't exist" do
    uuid = SecureRandom.uuid
    allow(SecureRandom).to receive(:uuid).and_return(uuid)

    expect(subject).to receive(:write_config).with(kind_of(String), include('user-id' => uuid))

    expect(subject.build_client.user_id).to eq(uuid)
  end

  context 'config file' do
    let(:path)     { File.expand_path(File.join('~', '.puppetlabs', 'etc', 'bolt', 'analytics.yaml')) }
    let(:old_path) { File.expand_path(File.join('~', '.puppetlabs', 'bolt', 'analytics.yaml')) }

    it 'loads config from user-level config directory' do
      allow(File).to receive(:exist?).with(path).and_return(true)
      allow(File).to receive(:exist?).with(old_path).and_return(false)

      expect(subject).to receive(:write_config).with(path, anything)

      subject.build_client
    end

    it 'falls back to the default project directory' do
      allow(File).to receive(:exist?).with(path).and_return(false)
      allow(File).to receive(:exist?).with(old_path).and_return(true)

      expect(subject).to receive(:write_config).with(old_path, anything)

      subject.build_client
    end

    it 'writes new config to the user-level config directory' do
      allow(File).to receive(:exist?).with(path).and_return(false)
      allow(File).to receive(:exist?).with(old_path).and_return(false)

      expect(subject).to receive(:write_config).with(path, anything)

      subject.build_client
    end

    it 'warns when user-level config and defaul project config both exist' do
      allow(File).to receive(:exist?).with(path).and_return(true)
      allow(File).to receive(:exist?).with(old_path).and_return(true)

      expect(subject).to receive(:write_config).with(path, anything)

      subject.build_client

      expect(@log_output.readlines).to include(/Detected analytics configuration files/)
    end
  end
end

describe Bolt::Analytics::Client do
  let(:uuid) { SecureRandom.uuid }
  let(:base_params) do
    {
      v: 1,
      an: 'bolt',
      av: Bolt::VERSION,
      cid: uuid,
      tid: 'UA-120367942-1',
      ul: Locale.current.to_rfc,
      aip: true,
      cd1: 'CentOS 7'
    }
  end

  before :each do
    allow_any_instance_of(described_class).to receive(:compute_os).and_return('CentOS 7')
  end

  subject { described_class.new(uuid) }

  describe "#screen_view" do
    it 'properly formats the screenview' do
      params = base_params.merge(t: 'screenview', cd: 'job_run')

      expect(subject).to receive(:submit).with params

      subject.screen_view('job_run')
    end

    it 'sets custom dimensions correctly' do
      params = base_params.merge(t: 'screenview', cd: 'job_run', cd2: 12, cd3: 17)

      expect(subject).to receive(:submit).with params

      subject.screen_view('job_run', inventory_nodes: 12, inventory_groups: 17)
    end

    it 'raises an error if an unknown custom dimension is specified' do
      expect { subject.screen_view('job_run', random_field: 'foo') }.to raise_error(/Unknown analytics key/)
    end
  end

  describe "#report_bundled_content" do
    before(:each) { subject.bundled_content = { 'Plan' => ['my_plan'] } }

    it 'reports bundled content' do
      expect(subject).to receive(:event).with('Bundled Content', 'Plan', label: 'my_plan')
      subject.report_bundled_content('Plan', 'my_plan')
    end

    it 'does not report other content' do
      expect(subject).not_to receive(:event)
      subject.report_bundled_content('Plan', 'other_plan')
    end
  end

  describe "#event" do
    it 'properly formats the event' do
      params = base_params.merge(t: 'event', ec: 'run', ea: 'task')

      expect(subject).to receive(:submit).with params

      subject.event('run', 'task')
    end

    it 'sends the event label if supplied' do
      params = base_params.merge(t: 'event', ec: 'run', ea: 'task', el: 'happy')

      expect(subject).to receive(:submit).with params

      subject.event('run', 'task', label: 'happy')
    end

    it 'sends the event metric if supplied' do
      params = base_params.merge(t: 'event', ec: 'run', ea: 'task', ev: 12)

      expect(subject).to receive(:submit).with params

      subject.event('run', 'task', value: 12)
    end
  end
end

describe Bolt::Analytics::NoopClient do
  describe "#screen_view" do
    it 'succeeds' do
      subject.screen_view('job_run')
    end
  end

  describe "#event" do
    it 'succeeds' do
      subject.event('run', 'task')
    end

    it 'succeeds with a label' do
      subject.event('run', 'task', label: 'happy')
    end

    it 'succeeds with a metric' do
      subject.event('run', 'task', value: 12)
    end
  end
end
