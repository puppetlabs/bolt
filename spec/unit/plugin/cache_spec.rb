# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/cache'

describe Bolt::Plugin::Cache do
  let(:env_var)   { 'BOLT_TEST_PLUGIN_VALUE' }
  let(:reference) do
    { '_plugin' => 'env_var',
      'var' => env_var,
      '_cache' => { 'ttl' => 120 } }
  end
  let(:plugin_cache) { Bolt::Plugin::Cache.new(reference, @tmpfile, {}) }

  around :each do |example|
    Tempfile.create do |file|
      @tmpfile = file.path
      example.run
    end
  end

  context "#validate" do
    context "if _cache is not a Hash" do
      let(:reference) {
        { '_plugin' => 'env_var',
          'var' => env_var,
          '_cache' => 120 }
      }
      it "fails" do
        expect { plugin_cache.validate }
          .to raise_error(Bolt::ValidationError, /_cache must be a Hash/)
      end
    end

    context "if _cache does not have a ttl key" do
      let(:reference) {
        { '_plugin' => 'env_var',
          'var' => env_var,
          '_cache' => { 'tl' => 120 } }
      }
      it "fails" do
        expect { plugin_cache.validate }
          .to raise_error(Bolt::ValidationError, /_cache must set 'ttl' key/)
      end
    end
  end

  context "#read_and_clean_cache" do
    context "with ttl 0" do
      let(:reference) {
        { '_plugin' => 'env_var',
          'var' => env_var,
          '_cache' => { 'ttl' => 0 } }
      }

      it "returns immediately" do
        expect(plugin_cache).not_to receive(:validate)
        plugin_cache.read_and_clean_cache
      end
    end

    context "with expired cache entries" do
      let(:cache_content) {
        { "abcde" => { 'result' => 'cache rules',
                       'mtime' => Time.now - 360,
                       'ttl' => 120 },
          "fghi" => { 'result' => 'everything around me',
                      'mtime' => Time.now.to_s, # Normalize for post-JSON comparison
                      'ttl' => 120 } }
      }

      it "cleans expired cache entries" do
        File.write(plugin_cache.plugin_cache_file, cache_content.to_json)
        plugin_cache.read_and_clean_cache
        fresh_cash = JSON.parse(File.read(plugin_cache.plugin_cache_file))
        expect(fresh_cash.key?('abcde')).to be false
        expect(fresh_cash['fghi']).to eq(cache_content['fghi'])
      end
    end

    context "without expired cache entries" do
      let(:cache_content) {
        { "abcde" => { 'result' => 'cache rules',
                       'mtime' => Time.now.to_s,
                       'ttl' => 120 } }
      }

      it "does not rewrite the cache file" do
        File.write(plugin_cache.plugin_cache_file, cache_content.to_json)

        expect(File).not_to receive(:write)
        plugin_cache.read_and_clean_cache
        same_cash = JSON.parse(File.read(plugin_cache.plugin_cache_file))
        expect(same_cash).to eq(cache_content)
      end
    end
  end
end
