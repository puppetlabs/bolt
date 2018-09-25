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
    end

    describe "when using a control repo-style Boltdir" do
      it 'uses the current directory if it has a bolt.yaml' do
        pwd = @tmpdir
        FileUtils.touch(pwd + 'bolt.yaml')
        expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(Bolt::Boltdir.new(pwd))
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

    it 'returns the default when no Boltdir is found' do
      pwd = @tmpdir
      expect(Bolt::Boltdir.find_boltdir(pwd)).to eq(Bolt::Boltdir.default_boltdir)
    end
  end
end
