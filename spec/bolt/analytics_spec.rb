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
    allow_any_instance_of(described_class).to receive(:compute_os).and_return(double('os_future', value: 'CentOS 7'))
  end

  subject { described_class.new(uuid) }

  describe "#screen_view" do
    it 'properly formats the screenview' do
      params = base_params.merge(t: 'screenview', cd: 'job_run')

      expect(subject).to receive(:submit).with params

      subject.screen_view('job_run')
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

      subject.event('run', 'task', 'happy')
    end

    it 'sends the event metric if supplied' do
      params = base_params.merge(t: 'event', ec: 'run', ea: 'task', ev: 12)

      expect(subject).to receive(:submit).with params

      subject.event('run', 'task', nil, 12)
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
      subject.event('run', 'task', 'happy')
    end

    it 'succeeds with a metric' do
      subject.event('run', 'task', nil, 12)
    end
  end
end
