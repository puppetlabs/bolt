# frozen_string_literal: true

module Bolt
  class Secret
    def self.execute(plugins, outputter, options)
      plugin = options[:plugin] || 'pkcs7'
      case options[:action]
      when 'createkeys'
        plugins.get_hook(plugin, :secret_createkeys).call
      when 'encrypt'
        encrypted = plugins.get_hook(plugin, :secret_encrypt).call('plaintext_value' => options[:object])
        outputter.print_message(encrypted)
      when 'decrypt'
        decrypted = plugins.get_hook(plugin, :secret_decrypt).call('encrypted_value' => options[:object])
        outputter.print_message(decrypted)
      end

      0
    end
  end
end
