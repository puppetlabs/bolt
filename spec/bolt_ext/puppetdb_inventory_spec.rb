# frozen_string_literal: true

require 'bolt_ext/puppetdb_inventory'
require 'bolt_spec/files'

describe "Bolt::PuppetDBInventory::CLI" do
  include BoltSpec::Files

  let(:args) {}
  subject { Bolt::PuppetDBInventory::CLI.new(args) }

  let(:pdb_args) { %w[--url localhost --cacert /tmp/ca.pem] }

  it { should be }

  context 'with --help' do
    let(:args) { '--help' }

    it 'displays usage' do
      expect { subject.run }.to output(/Usage: bolt-inventory-pdb/).to_stdout
    end
  end

  it 'requires an inventory file' do
    expect { subject.run }.to raise_error('Please specify an input file (see --help for details)')
  end

  context 'with file name' do
    let(:args) { pdb_args + ['/path/does/not/exist'] }

    it 'errors if the file cannot be read' do
      expect { subject.run }.to raise_error("Can't read the inventory file /path/does/not/exist")
    end
  end

  it 'updates the inventory file' do
    content = <<INVENTORY
---
config:
  transport: pcp
groups:
- name: windows
  query: inventory[certname] { facts.os.family = "windows" }
  facts:
    osfamily: windows
INVENTORY

    with_tempfile_containing('inventory', content, '.yml') do |file|
      nodes = %w[nodea nodeb nodec]
      pdb_client = double('pdb')
      expect(pdb_client).to receive(:query_certnames).and_return([], nodes)
      expect(Bolt::PuppetDB::Client).to receive(:new).and_return(pdb_client)
      cli = Bolt::PuppetDBInventory::CLI.new([file.path, '--output', file.path] + pdb_args)
      cli.run

      expected = YAML.safe_load(content)
      expected['groups'][0]['nodes'] = nodes
      expected['nodes'] = []
      expect(YAML.load_file(file)).to eq(expected)
    end
  end
end
