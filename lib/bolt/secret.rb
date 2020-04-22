# frozen_string_literal: true

require 'bolt/plugin'

module Bolt
  class Secret
    KNOWN_KEYS = {
      'createkeys' => %w[keysize private_key public_key],
      'encrypt'    => %w[public_key],
      'decrypt'    => %w[private_key public_key]
    }.freeze

    def self.execute(plugins, outputter, options)
      name   = options[:plugin] || 'pkcs7'
      plugin = plugins.by_name(name)

      unless plugin
        raise Bolt::Plugin::PluginError::Unknown, name
      end

      case options[:action]
      when 'createkeys'
        opts = { 'force' => options[:force] }.compact
        result = plugins.get_hook(name, :secret_createkeys).call(opts)
        outputter.print_message(result)
      when 'encrypt'
        encrypted = plugins.get_hook(name, :secret_encrypt).call('plaintext_value' => options[:object])
        outputter.print_message(encrypted)
      when 'decrypt'
        decrypted = plugins.get_hook(name, :secret_decrypt).call('encrypted_value' => options[:object])
        outputter.print_message(decrypted)
      end

      0
    end
  end
end
