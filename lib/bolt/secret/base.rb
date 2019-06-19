# frozen_string_literal: true

module Bolt
  class Secret
    class Base
      def hooks
        %w[inventory_config_lookup encrypt decrypt create_keys]
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
        encrypted = encrypt_value(opts['plaintext-value'])
        encode(encrypted)
      end

      def secret_decrypt(opts)
        raw, _plugin = decode(opts['encrypted-value'])
        decrypt_value(raw)
      end
      alias inventory_config_lookup secret_decrypt

      def validate_inventory_config_lookup(opts)
        decode(opts['encrypted-value'])
      end
    end
  end
end
