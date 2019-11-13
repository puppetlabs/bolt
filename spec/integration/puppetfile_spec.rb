# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/files'

describe "installing puppetfiles" do
  include BoltSpec::Integration

  let(:synced_modules) { [] }
  let(:root) { Dir.mktmpdir }
  let(:boltdir) { File.join(root, 'Boltdir') }
  let(:module_source) { Dir.mktmpdir }

  def git(*args)
    _output, status = Open3.capture2('git', *args)
    expect(status).to eq(0)
  end

  def make_module(name, tasks, plans)
    mod = File.join(module_source, name)
    FileUtils.mkdir_p(File.join(mod, 'tasks'))
    FileUtils.mkdir_p(File.join(mod, 'plans'))
    Dir.chdir(mod) do
      tasks.each do |task|
        FileUtils.touch(File.join(mod, 'tasks', "#{task}.sh"))
      end
      plans.each do |plan|
        File.write(File.join(mod, 'plans', "#{plan}.pp"), "plan #{name}::#{plan}() { }")
      end

      git('init')
      git('config', 'user.name', 'Bolt Tests')
      git('config', 'user.email', 'test@example.com')
      git('add', 'tasks', 'plans')
      git('commit', '-m', 'add modules')
    end
  end

  it 'installs the modules in the Puppetfile' do
    make_module('foo', %w[a b], %w[c d])
    make_module('bar', %w[e f], %w[g h])
    Dir.mkdir(boltdir)
    File.write(File.join(boltdir, 'Puppetfile'), <<-PUPPETFILE)
    forge 'https://forge.example.com'

    mod 'tester-foo', git: 'file://#{module_source}/foo', ref: 'master'
    mod 'tester-bar', git: 'file://#{module_source}/bar', ref: 'master'
    PUPPETFILE

    result = JSON.parse(run_cli(%W[puppetfile install --boltdir #{boltdir}]))

    expect(result['success']).to eq(true)
    expect(result['puppetfile']).to eq(File.join(boltdir, 'Puppetfile'))
    expect(result['moduledir']).to eq(File.join(boltdir, 'modules'))
    expect(Dir.exist?(File.join(boltdir, '.resource_types')))

    result = JSON.parse(run_cli(%W[task show --boltdir #{boltdir}]))
    installed_tasks = Set.new(result['tasks'].map(&:first))
    expect(installed_tasks).to be_superset(Set.new(%w[foo::a foo::b bar::e bar::f]))

    result = JSON.parse(run_cli(%W[plan show --boltdir #{boltdir}]))
    installed_plans = Set.new(result['plans'].map(&:first))
    expect(installed_plans).to be_superset(Set.new(%w[foo::c foo::d bar::g bar::h]))
  end
end
