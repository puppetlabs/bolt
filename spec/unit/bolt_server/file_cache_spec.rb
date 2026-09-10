# frozen_string_literal: true

require 'spec_helper'
require 'bolt_server/file_cache'
require 'digest'
require 'tempfile'
require 'tmpdir'

describe BoltServer::FileCache do
  let(:cache_dir) { Dir.mktmpdir }
  let(:config)    { { 'cache-dir' => cache_dir } }
  let(:cache)     { BoltServer::FileCache.new(config, do_purge: false) }

  after(:each) { FileUtils.rm_rf(cache_dir) }

  describe '#tmppath' do
    it 'returns the tmp subdirectory of the cache dir' do
      expect(cache.tmppath).to eq(File.join(cache_dir, 'tmp'))
    end
  end

  describe '#setup' do
    it 'creates the cache directory and tmp subdirectory' do
      FileUtils.rm_rf(cache_dir)
      cache.setup
      expect(Dir.exist?(cache_dir)).to be true
      expect(Dir.exist?(cache.tmppath)).to be true
    end

    it 'returns self' do
      expect(cache.setup).to eq(cache)
    end
  end

  describe '#ssl_cert' do
    it 'reads the ssl cert file' do
      cert_path = File.join(cache_dir, 'cert.pem')
      File.write(cert_path, 'cert-content')
      config['ssl-cert'] = cert_path
      expect(cache.ssl_cert).to eq('cert-content')
    end

    it 'memoizes the result' do
      cert_path = File.join(cache_dir, 'cert.pem')
      File.write(cert_path, 'cert-content')
      config['ssl-cert'] = cert_path
      cache.ssl_cert
      File.write(cert_path, 'changed')
      expect(cache.ssl_cert).to eq('cert-content')
    end
  end

  describe '#ssl_key' do
    it 'reads the ssl key file' do
      key_path = File.join(cache_dir, 'key.pem')
      File.write(key_path, 'key-content')
      config['ssl-key'] = key_path
      expect(cache.ssl_key).to eq('key-content')
    end
  end

  describe '#check_file' do
    let(:content)   { 'hello world' }
    let(:sha)       { Digest::SHA256.hexdigest(content) }
    let(:file_path) { File.join(cache_dir, 'testfile') }

    it 'returns true when the file exists with the correct sha' do
      File.write(file_path, content)
      expect(cache.check_file(file_path, sha)).to be true
    end

    it 'returns false when the file does not exist' do
      expect(cache.check_file(file_path, sha)).to be false
    end

    it 'returns false when the file has the wrong sha' do
      File.write(file_path, content)
      expect(cache.check_file(file_path, 'wrongsha')).to be false
    end
  end

  describe '#serial_execute' do
    it 'executes the block and returns the value' do
      expect(cache.serial_execute { 42 }).to eq(42)
    end

    it 'raises when the block raises' do
      expect { cache.serial_execute { raise 'boom' } }.to raise_error('boom')
    end
  end

  describe '#create_cache_dir' do
    it 'creates and returns the sha-named directory under the cache dir' do
      dir = cache.create_cache_dir('abc123')
      expect(dir).to eq(File.join(cache_dir, 'abc123'))
      expect(Dir.exist?(dir)).to be true
    end

    it 'does not raise if the directory already exists' do
      cache.create_cache_dir('abc123')
      expect { cache.create_cache_dir('abc123') }.not_to raise_error
    end
  end

  describe '#download_file' do
    let(:content)   { 'file content' }
    let(:sha)       { Digest::SHA256.hexdigest(content) }
    let(:file_path) { File.join(cache_dir, 'myfile.txt') }
    let(:uri)       { { 'path' => '/path/to/file', 'params' => {} } }

    before(:each) { FileUtils.mkdir_p(cache.tmppath) }

    it 'returns the path immediately if the file is already cached' do
      File.write(file_path, content)
      expect(cache).not_to receive(:request_file)
      expect(cache.download_file(file_path, sha, uri)).to eq(file_path)
    end

    it 'downloads, validates, and moves the file when not cached' do
      allow(cache).to receive(:request_file) do |_path, _params, file|
        file.write(content)
        file.flush
      end
      result = cache.download_file(file_path, sha, uri)
      expect(result).to eq(file_path)
      expect(File.read(file_path)).to eq(content)
    end

    it 'raises an error when the downloaded checksum does not match' do
      allow(cache).to receive(:request_file) do |_path, _params, file|
        file.write('corrupted content')
      end
      expect { cache.download_file(file_path, sha, uri) }
        .to raise_error(BoltServer::FileCache::Error, /did not match checksum/)
    end
  end

  describe '#update_file' do
    let(:content)  { 'task content' }
    let(:sha)      { Digest::SHA256.hexdigest(content) }
    let(:file_data) do
      {
        'sha256'   => sha,
        'filename' => 'mytask.sh',
        'uri'      => { 'path' => '/tasks/mytask.sh', 'params' => {} }
      }
    end

    before(:each) { FileUtils.mkdir_p(cache.tmppath) }

    it 'returns the cached path if the file already exists with the correct sha' do
      dir = cache.create_cache_dir(sha)
      file_path = File.join(dir, 'mytask.sh')
      File.write(file_path, content)
      expect(cache).not_to receive(:download_file)
      expect(cache.update_file(file_data)).to eq(file_path)
    end

    it 'queues a download when the file is not cached' do
      allow(cache).to receive(:download_file).and_return('/downloaded/path')
      cache.update_file(file_data)
      expect(cache).to have_received(:download_file)
    end
  end

  describe '#expire' do
    before(:each) { FileUtils.mkdir_p(cache.tmppath) }

    it 'removes directories older than the ttl' do
      old_dir = File.join(cache_dir, 'old_sha')
      FileUtils.mkdir_p(old_dir)
      FileUtils.touch(old_dir, mtime: Time.now - 100)
      cache.expire(50, 60)
      expect(Dir.exist?(old_dir)).to be false
    end

    it 'keeps directories newer than the ttl' do
      new_dir = File.join(cache_dir, 'new_sha')
      FileUtils.mkdir_p(new_dir)
      cache.expire(3600, 60)
      expect(Dir.exist?(new_dir)).to be true
    end

    it 'does not remove the tmppath even when it is old' do
      FileUtils.touch(cache.tmppath, mtime: Time.now - 100)
      cache.expire(50, 60)
      expect(Dir.exist?(cache.tmppath)).to be true
    end
  end

  describe '#get_cached_project_file' do
    it 'returns the file content if the file exists' do
      dir = cache.create_cache_dir('myproject')
      File.write(File.join(dir, 'data.json'), '{"key":"value"}')
      expect(cache.get_cached_project_file('myproject', 'data.json')).to eq('{"key":"value"}')
    end

    it 'returns nil if the file does not exist' do
      expect(cache.get_cached_project_file('missing_project', 'data.json')).to be_nil
    end
  end

  describe '#cache_project_file' do
    it 'writes the data to the correct cache path' do
      cache.cache_project_file('myproject', 'data.json', '{"key":"value"}')
      file_path = File.join(cache_dir, 'myproject', 'data.json')
      expect(File.read(file_path)).to eq('{"key":"value"}')
    end
  end

  describe '#request_file' do
    let(:cache)   { BoltServer::FileCache.new(config.merge('file-server-uri' => 'https://example.com'), do_purge: false) }
    let(:tmpfile) { Tempfile.new('test', cache_dir) }

    after(:each) { tmpfile.close! }

    it 'writes response chunks to the file on success' do
      response = double('response', code: '200')
      allow(response).to receive(:read_body).and_yield('chunk1').and_yield('chunk2')
      allow(cache).to receive(:client).and_return(double('client').tap do |c|
        allow(c).to receive(:request).and_yield(response)
      end)
      path = tmpfile.path
      cache.request_file('/path', {}, tmpfile)
      expect(File.read(path)).to eq('chunk1chunk2')
    end

    it 'raises an Error on a non-200 response' do
      response = double('response', code: '404', body: 'Not Found')
      allow(cache).to receive(:client).and_return(double('client').tap do |c|
        allow(c).to receive(:request).and_yield(response)
      end)
      expect { cache.request_file('/path', {}, tmpfile) }
        .to raise_error(BoltServer::FileCache::Error, /Failed to download file/)
    end

    it 'wraps network errors in a FileCache::Error' do
      allow(cache).to receive(:client).and_return(double('client').tap do |c|
        allow(c).to receive(:request).and_raise(SocketError, 'connection refused')
      end)
      expect { cache.request_file('/path', {}, tmpfile) }
        .to raise_error(BoltServer::FileCache::Error, /Failed to download file: connection refused/)
    end

    it 're-raises Bolt::Error without wrapping' do
      bolt_error = BoltServer::FileCache::Error.new('original error')
      allow(cache).to receive(:client).and_return(double('client').tap do |c|
        allow(c).to receive(:request).and_raise(bolt_error)
      end)
      expect { cache.request_file('/path', {}, tmpfile) }
        .to raise_error(BoltServer::FileCache::Error, 'original error')
    end
  end
end
