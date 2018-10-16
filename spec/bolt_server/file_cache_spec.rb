# frozen_string_literal: true

require 'fileutils'
require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/bolt_server'
require 'bolt_server/config'
require 'bolt_server/file_cache'
require 'json'
require 'rack/test'

describe BoltServer::FileCache, puppetserver: true do
  include BoltSpec::BoltServer

  before(:all) do
    begin
      get_task_data('sample::echo')
    rescue StandardError => e
      raise "Could not get sample::echo from puppetserver. Tests will fail: #{e}"
    end
  end

  before(:each) do
    FileUtils.rm_rf(default_config['cache-dir'])
  end

  let(:config) do
    BoltServer::Config.new(default_config)
  end

  let(:file_cache) do
    cache = BoltServer::FileCache.new(config)
    cache.setup
    cache
  end

  it 'gets files from puppetserver' do
    data = get_task_data('sample::echo')['files'].first

    path = file_cache.update_file(data)
    expect(path).to eq(File.join(default_config['cache-dir'], data['sha256'], data['filename']))
    expect(File.read(path)).to eq("#!/bin/sh\n\necho $(hostname) got passed the message: $PT_message\n")
  end

  it 'overwrites bad files' do
    data = get_task_data('sample::echo')['files'].first
    expected_path = File.join(default_config['cache-dir'], data['sha256'], data['filename'])
    FileUtils.mkdir_p(File.dirname(expected_path))
    File.write(expected_path, "bad-data")

    path = file_cache.update_file(data)
    expect(path).to eq(expected_path)
    expect(File.read(path)).to eq("#!/bin/sh\n\necho $(hostname) got passed the message: $PT_message\n")
  end

  it 'does not download existing files' do
    data = get_task_data('sample::echo')['files'].first
    file_content = 'good-data'
    data['sha256'] = Digest::SHA256.hexdigest(file_content)
    expected_path = File.join(default_config['cache-dir'], data['sha256'], data['filename'])
    FileUtils.mkdir_p(File.dirname(expected_path))
    File.write(expected_path, file_content)
    mtime = File.mtime(expected_path)
    sleep(1)

    path = file_cache.update_file(data)
    expect(path).to eq(expected_path)
    expect(File.read(path)).to eq(file_content)
    expect(File.mtime(path)).not_to eq(mtime)
  end

  it 'fails when the downloaded file is invalid' do
    data = get_task_data('sample::echo')['files'].first
    data['sha256'] = Digest::SHA256.hexdigest('bad-data')

    expect { file_cache.update_file(data) }.to raise_error(/did not match checksum/)
  end
end
