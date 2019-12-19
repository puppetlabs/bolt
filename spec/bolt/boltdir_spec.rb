# frozen_string_literal: true

require 'spec_helper'
require 'bolt/boltdir'

describe Bolt::Boltdir do
  describe "::find_boltdir" do
    let(:boltdir_path) { @tmpdir + 'foo' + 'Boltdir' }
    let(:boltdir) { Bolt::Boltdir.new(boltdir_path) }

    around(:each) do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = Pathname.new(tmpdir)
        FileUtils.mkdir_p(boltdir_path)
        example.run
      end
    end

    describe "when the Boltdir is named Boltdir" do
      it 'finds Boltdir from inside Boltdir' do
        pwd = boltdir_path
        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(boltdir)
      end

      it 'finds Boltdir from the parent directory' do
        pwd = boltdir_path.parent
        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(boltdir)
      end

      it 'does not find Boltdir from the grandparent directory' do
        pwd = boltdir_path.parent.parent
        expect(Bolt::Boltdir.find_boltdir(pwd)).not_to eq(boltdir)
      end

      it 'finds the Boltdir from a sibling directory' do
        pwd = boltdir_path.parent + 'bar'
        FileUtils.mkdir_p(pwd)

        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(boltdir)
      end

      it 'finds the Boltdir from a child directory' do
        pwd = boltdir_path + 'baz'
        FileUtils.mkdir_p(pwd)

        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(boltdir)
      end

      it 'loads config from bolt.yml inside a Boltdir if bolt.yml exists' do
        pwd = boltdir_path
        FileUtils.touch(pwd + 'bolt.yml')
        boltdir = Bolt::Boltdir.find_boltdir(pwd)
        expect(boltdir.config_file.basename.to_s).to eq('bolt.yml')
      end

      it 'loads config from bolt.yaml inside a Boltdir if no config exists' do
        pwd = boltdir_path
        boltdir = Bolt::Boltdir.find_boltdir(pwd)
        expect(boltdir.config_file.basename.to_s).to eq('bolt.yaml')
      end
    end

    describe "when using a control repo-style Boltdir" do
      it 'uses the current directory if it has a bolt.yaml' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yaml')
        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(Bolt::Boltdir.new(pwd))
      end

      it 'uses the current directory if it has a bolt.yml' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yml')
        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(Bolt::Boltdir.new(pwd))
      end

      it 'prefers a bolt.yaml over bolt.yml' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yml')
        FileUtils.touch(pwd + 'bolt.yaml')
        boltdir = Bolt::Boltdir.find_boltdir(pwd)
        expect(boltdir.config_file.basename.to_s).to eq('bolt.yaml')
      end

      it 'ignores non-Boltdir children with bolt.yaml' do
        pwd = @tmpdir
        FileUtils.mkdir_p(pwd + 'bar')
        FileUtils.touch(pwd + 'bar' + 'bolt.yaml')

        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(Bolt::Boltdir.default_boltdir)
      end

      it 'prefers a directory called Boltdir over the local directory' do
        pwd = boltdir_path.parent
        FileUtils.touch(pwd + 'bolt.yaml')

        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(boltdir)
      end

      it 'prefers a directory called Boltdir over the parent directory' do
        pwd = boltdir_path.parent + 'bar'
        FileUtils.mkdir_p(pwd)
        FileUtils.touch(boltdir_path.parent + 'bolt.yaml')

        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(boltdir)
      end
    end

    describe 'loading inventory files' do
      it 'loads inventory.yaml from the boltdir' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yml')
        FileUtils.touch(pwd + 'inventory.yaml')
        boltdir = Bolt::Boltdir.find_boltdir(pwd)
        expect(boltdir.inventory_file.basename.to_s).to eq('inventory.yaml')
      end

      it 'loads inventory.yml from the boltdir' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yml')
        FileUtils.touch(pwd + 'inventory.yml')
        boltdir = Bolt::Boltdir.find_boltdir(pwd)
        expect(boltdir.inventory_file.basename.to_s).to eq('inventory.yml')
      end

      it 'prefers inventory.yaml' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yml')
        FileUtils.touch(pwd + 'inventory.yml')
        FileUtils.touch(pwd + 'inventory.yaml')
        boltdir = Bolt::Boltdir.find_boltdir(pwd)
        expect(boltdir.inventory_file.basename.to_s).to eq('inventory.yaml')
      end
    end

    describe 'when setting a type' do
      it 'sets type to embedded when a Boltdir is used' do
        pwd = boltdir_path.parent
        expect(Bolt::Boltdir.find_boltdir(pwd).type).to eq('embedded')
      end

      it 'sets type to local when a bolt.yaml is used' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yaml')

        expect(Bolt::Boltdir.find_boltdir(pwd).type).to eq('local')
      end

      it 'sets type to local when a bolt.yaml is used' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yml')

        expect(Bolt::Boltdir.find_boltdir(pwd).type).to eq('local')
      end

      it 'sets type to user when the default is used' do
        pwd = @tmpdir
        expect(Bolt::Boltdir.find_boltdir(pwd).type).to eq('user')
      end
    end

    it 'returns the default when no Boltdir is found' do
      pwd = @tmpdir
      expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(Bolt::Boltdir.default_boltdir)
    end
  end
end
