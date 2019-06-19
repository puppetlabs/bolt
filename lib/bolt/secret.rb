# frozen_string_literal: true

module Bolt
  class Secret
    def self.execute(plugins, outputter, options)
      enc = plugins.by_name('pkcs7')
      case options[:action]
      when 'createkeys'
        enc.secret_createkeys
      when 'encrypt'
        outputter.print_message(enc.secret_encrypt('plaintext-value' => options[:object]))
      when 'decrypt'
        outputter.print_message(enc.secret_decrypt('encrypted-value' => options[:object]))
      end

      0
    end
  end
end
