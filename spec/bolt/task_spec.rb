# frozen_string_literal: true

require 'spec_helper'
require 'bolt/target'
require 'bolt/task'

describe Bolt::Task do
  describe "#select_implementation" do
    let(:target) { Bolt::Target.new('example') }
    let(:files) {
      [
        { 'name' => 'foo.sh',  'path' => '/foo.sh' },
        { 'name' => 'foo.ps1', 'path' => 'C:/foo.ps1' },
        { 'name' => 'foo.rb',  'path' => '/foo.rb' }
      ]
    }
    let(:implementations) { [] }
    let(:metadata) { { 'implementations' => implementations } }
    let(:task) { Bolt::Task.new(name: 'foo', files: files, metadata: metadata) }

    before :each do
      allow(target).to receive(:features).and_return(Set.new(['powershell']))
    end

    context 'no metadata present' do
      let(:metadata) { {} }

      it { expect(task.select_implementation(target)).to eq(files.first) }
    end

    context 'implementations have no requirements' do
      let(:implementations) {
        [{ 'name' => 'foo.sh', 'requirements' => [] },
         { 'name' => 'foo.ps1', 'requirements' => [] }]
      }

      it { expect(task.select_implementation(target)).to eq(files.first) }
    end

    context 'second implementation matches available feature' do
      let(:implementations) {
        [{ 'name' => 'foo.sh', 'requirements' => ['shell'] },
         { 'name' => 'foo.ps1', 'requirements' => ['powershell'] }]
      }

      it { expect(task.select_implementation(target)).to eq(files[1]) }
    end

    context 'first implementation requires extra features' do
      let(:implementations) {
        [{ 'name' => 'foo.rb', 'requirements' => ['powershell', 'puppet-agent'] },
         { 'name' => 'foo.ps1', 'requirements' => ['powershell'] }]
      }

      it { expect(task.select_implementation(target)).to eq(files[1]) }

      it 'uses additional features passed as arguments' do
        expect(task.select_implementation(target, ['puppet-agent'])).to eq(files[2])
      end
    end

    context 'no suitable implementation' do
      let(:implementations) {
        [{ 'name' => 'foo.rb', 'requirements' => ['powershell', 'puppet-agent'] },
         { 'name' => 'foo.ps1', 'requirements' => %w[powershell foobar] }]
      }

      it {
        expect { task.select_implementation(target) }.to raise_error('No suitable implementation of foo for example')
      }
    end
  end
end
