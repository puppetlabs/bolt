# frozen_string_literal: true

module Bolt
  class Secret
    class Base
      def hooks
        %i[resolve_reference secret_encrypt secret_decrypt secret_createkeys validate_resolve_reference]
      end

      def encode(raw)
        coded = Base64.encode64(raw).strip
        "ENC[#{name.upcase},#{coded}]"
      end

      def decode(code)
        format = %r{\AENC\[(?<plugin>\w+),(?<encoded>[\w\s+-=/]+)\]\s*\z}
        match = format.match(code)

        raise Bolt::ValidationError, "Could not parse as an encrypted value: #{code}" unless match

        raw = Base64.decode64(match[:encoded])
        [raw, match[:plugin]]
      end

      def secret_encrypt(opts)
        encrypted = encrypt_value(opts['plaintext_value'])
        encode(encrypted)
      end

      def secret_decrypt(opts)
        raw, _plugin = decode(opts['encrypted_value'])
        decrypt_value(raw)
      end
      alias resolve_reference secret_decrypt

      def validate_resolve_reference(opts)
        decode(opts['encrypted_value'])
      end
    end
  end
end
