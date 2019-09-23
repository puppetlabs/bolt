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
    expected_dir = File.join(default_config['cache-dir'], data['sha256'])
    expected_path = File.join(expected_dir, data['filename'])
    FileUtils.mkdir_p(expected_dir)
    File.write(expected_path, file_content)
    mtime = File.mtime(expected_dir)
    sleep(1)

    path = file_cache.update_file(data)
    expect(path).to eq(expected_path)
    expect(File.read(path)).to eq(file_content)
    expect(File.mtime(expected_dir)).not_to eq(mtime)
  end

  it 'purges old files on startup' do
    file_content = 'good-data'
    sha = Digest::SHA256.hexdigest(file_content)
    expected_dir = File.join(default_config['cache-dir'], sha)
    FileUtils.mkdir_p(expected_dir)
    File.write(File.join(expected_dir, 'task'), file_content)
    FileUtils.touch(expected_dir, mtime: Time.now - (BoltServer::FileCache::PURGE_TTL + 1))
    FileUtils.touch(file_cache.tmppath, mtime: Time.now - (BoltServer::FileCache::PURGE_TTL + 1))

    expect(file_cache).to be
    gone = 10.times do
      sleep 0.1
      break true unless File.exist?(expected_dir)
    end
    expect(gone).to eq(true)
    expect(File.exist?(file_cache.tmppath)).to eq(true)
  end

  it 'purges old files after the purge_interval' do
    file_content = 'good-data'
    sha = Digest::SHA256.hexdigest(file_content)
    expected_dir = File.join(default_config['cache-dir'], sha)
    FileUtils.mkdir_p(expected_dir)
    File.write(File.join(expected_dir, 'task'), file_content)

    cache = BoltServer::FileCache.new(config, purge_interval: 1)
    cache.setup

    FileUtils.touch(expected_dir, mtime: Time.now - (BoltServer::FileCache::PURGE_TTL + 1))
    FileUtils.touch(file_cache.tmppath, mtime: Time.now - (BoltServer::FileCache::PURGE_TTL + 1))
    gone = 10.times do
      sleep 0.5
      break true unless File.exist?(expected_dir)
    end
    expect(gone).to eq(true)
    expect(File.exist?(file_cache.tmppath)).to eq(true)
  end

  it 'fails when the downloaded file is invalid' do
    data = get_task_data('sample::echo')['files'].first
    data['sha256'] = Digest::SHA256.hexdigest('bad-data')

    expect { file_cache.update_file(data) }.to raise_error(/did not match checksum/)
  end

  context 'When do_purge is false' do
    let(:file_cache) do
      BoltServer::FileCache.new(config, do_purge: false)
    end

    it 'will not set up purge timer' do
      expect(file_cache.instance_variable_get(:@purge)).to be_nil
    end
  end

  context 'When do_purge is true' do
    let(:file_cache) do
      BoltServer::FileCache.new(config, do_purge: true)
    end

    it 'will create and run the purge timer' do
      expect(file_cache.instance_variable_get(:@purge)).to be_a(Concurrent::TimerTask)
    end
  end

  context 'When do_purge is true and cache_dir_mutex is specified' do
    let(:other_mutex) { double('other_mutex') }
    let(:file_cache) do
      BoltServer::FileCache.new(config,
                                purge_interval: 1,
                                purge_timeout: 1,
                                purge_ttl: 1,
                                cache_dir_mutex: other_mutex,
                                do_purge: true)
    end

    it 'will create and run the purge timer' do
      expect(file_cache.instance_variable_get(:@purge)).to be_a(Concurrent::TimerTask)
      expect(file_cache.instance_variable_get(:@cache_dir_mutex)).to eq(other_mutex)
      expect(other_mutex).to receive(:with_write_lock)

      file_cache
      sleep 2 # allow time for the purge timer to fire
    end
  end
end
