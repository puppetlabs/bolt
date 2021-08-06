# frozen_string_literal: true

require 'bolt/module_installer/puppetfile/git_module'

describe Bolt::ModuleInstaller::Puppetfile::GitModule do
  let(:name) { 'yaml' }
  let(:git)  { 'https://github.com/puppetlabs/puppetlabs-yaml' }
  let(:ref)  { '79f98ffd3faf8d3badb1084a676e5fc1cbac464e' }
  let(:mod)  { described_class.new(name, git, ref) }

  context '#to_spec' do
    it 'returns a Puppetfile spec' do
      expect(mod.to_spec).to eq(<<~SPEC.chomp)
        mod '#{name}',
          git: '#{git}',
          ref: '#{ref}'
      SPEC
    end
  end

  context '#to_hash' do
    it 'returns a hash with the module attributes' do
      expect(mod.to_hash).to eq(
        'git' => git,
        'ref' => ref
      )
    end
  end
end
