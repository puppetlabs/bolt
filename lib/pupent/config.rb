# frozen_string_literal: true

require 'json'
require 'fileutils'

module PupEnt
  module Config
    DEFAULT_PUPENT_LOCATION = File.join(ENV['HOME'], ".puppetlabs", "pupent")
    DEFAULTS = {
      token_file: File.join(DEFAULT_PUPENT_LOCATION, "token"),
      log_level: "info",
      # pupent access defaults
      lifetime: "15m"
    }.freeze

    def self.read_config(file_location)
      FileUtils.mkdir_p(DEFAULT_PUPENT_LOCATION)
      file_location ||= File.join(DEFAULT_PUPENT_LOCATION, "config.json")
      parsed_data = nil
      # Use a+ so it won't fail if the config file doesn't exist, just create an empty one
      File.open(file_location, 'a+') do |fd|
        config_data = fd.read
        parsed_data = if config_data && !config_data.empty?
                        JSON.parse(config_data)
                      else
                        {}
                      end
      end
      parsed_data.transform_keys! { |key| key.to_s.downcase.gsub("-", "_").to_sym }
      DEFAULTS.merge(parsed_data)
    end

    def self.save_config(parsed_options)
      file_location ||= File.join(DEFAULT_PUPENT_LOCATION, "config.json")
      File.open(file_location, 'w') do |fd|
        config_to_save = parsed_options.slice(:token_file, :ca_cert, :pe_host, :service_url)
        fd.write(JSON.pretty_generate(config_to_save))
      end
    end
  end
end
