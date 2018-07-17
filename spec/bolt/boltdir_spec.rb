# frozen_string_literal: true

require 'spec_helper'
require 'bolt/boltdir'

describe Bolt::Boltdir do
  describe "::find_boltdir" do
    let(:boltdir_path) { Pathname.new(File.join(@tmpdir, "foo", "Boltdir")) }
    let(:boltdir) { Bolt::Boltdir.new(boltdir_path) }

    around(:each) do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        FileUtils.mkdir_p(boltdir_path)
        example.run
      end
    end

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
end
