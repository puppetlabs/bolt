# frozen_string_literal: true

require 'bolt/secret/base'
require 'fileutils'

module Bolt
  class Plugin
    class Pkcs7 < Bolt::Secret::Base
      def self.validate_config(config = {})
        known_keys = %w[private-key public-key keysize]
        known_keys.each do |key|
          unless key.is_a? String
            raise Bolt::ValidationError, "Invalid config for pkcs7 plugin: '#{key}' is not a String"
          end
        end

        config.each_key do |key|
          unless known_keys.include?(key)
            raise Bolt::ValidationError, "Unpexpected key in pkcs7 plugin config: #{key}"
          end
        end
      end

      def name
        'pkcs7'
      end

      def initialize(config:, context:, **_opts)
        self.class.validate_config(config)
        require 'openssl'
        @context = context
        @options = config || {}
        @logger = Logging.logger[self]
      end

      def boltdir
        @context.boltdir
      end

      def private_key_path
        path = @options['private-key'] || 'keys/private_key.pkcs7.pem'
        path = File.expand_path(path, boltdir)
        @logger.debug("Using private-key: #{path}")
        path
      end

      def private_key
        @private_key ||= OpenSSL::PKey::RSA.new(File.read(private_key_path))
      end

      def public_key_path
        path = @options['public-key'] || 'keys/public_key.pkcs7.pem'
        path = File.expand_path(path, boltdir)
        @logger.debug("Using public-key: #{path}")
        path
      end

      def public_key
        @public_key ||= OpenSSL::X509::Certificate.new(File.read(public_key_path))
      end

      def keysize
        @options['keysize'] || 2048
      end

      # The following implementations are intended to be compatible with hiera-eyaml
      def encrypt_value(plaintext)
        cipher = OpenSSL::Cipher::AES.new(256, :CBC)
        OpenSSL::PKCS7.encrypt([public_key], plaintext, cipher, OpenSSL::PKCS7::BINARY).to_der
      end

      def decrypt_value(ciphertext)
        pkcs7 = OpenSSL::PKCS7.new(ciphertext)
        pkcs7.decrypt(private_key, public_key)
      end

      def secret_createkeys
        key = OpenSSL::PKey::RSA.new(keysize)

        cert = OpenSSL::X509::Certificate.new
        cert.subject = OpenSSL::X509::Name.parse('/')
        cert.serial = 1
        cert.version = 2
        cert.not_before = Time.now
        cert.not_after = Time.now + 50 * 365 * 24 * 60 * 60
        cert.public_key = key.public_key
        cert.sign(key, OpenSSL::Digest.new('SHA512'))

        @logger.warn("Overwriting private-key '#{private_key_path}'") if File.exist?(private_key_path)
        @logger.warn("Overwriting public-key '#{public_key_path}'") if File.exist?(public_key_path)

        private_keydir = File.dirname(private_key_path)
        FileUtils.mkdir_p(private_keydir) unless File.exist?(private_keydir)
        FileUtils.touch(private_key_path)
        File.chmod(0o600, private_key_path)
        File.write(private_key_path, key.to_pem)

        public_keydir = File.dirname(public_key_path)
        FileUtils.mkdir_p(public_keydir) unless File.exist?(public_keydir)
        File.write(public_key_path, cert.to_pem)
      end
    end
  end
end
