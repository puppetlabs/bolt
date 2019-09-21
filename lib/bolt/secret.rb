# frozen_string_literal: true

module Bolt
  class Secret
    def self.execute(plugins, outputter, options)
      case options[:action]
      when 'createkeys'
        plugins.get_hook('pkcs7', :secret_createkeys).call
      when 'encrypt'
        encrypted = plugins.get_hook('pkcs7', :secret_encrypt).call('plaintext-value' => options[:object])
        outputter.print_message(encrypted)
      when 'decrypt'
        decrypted = plugins.get_hook('pkcs7', :secret_decrypt).call('encrypted-value' => options[:object])
        outputter.print_message(decrypted)
      end

      0
    end
  end
end
