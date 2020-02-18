# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class WinRM < Transport
      OPTIONS = {
        "cacert"          => "The path to the CA certificate.",
        "connect-timeout" => "How long Bolt should wait when establishing connections.",
        "extensions"      => "List of file extensions that are accepted for scripts or tasks. "\
                              "Scripts with these file extensions rely on the target's file type "\
                              "association to run. For example, if Python is installed on the system, "\
                              "a `.py` script runs with `python.exe`. The extensions `.ps1`, `.rb`, and "\
                              "`.pp` are always allowed and run via hard-coded executables.",
        "file-protocol"   => "Which file transfer protocol to use. Either `winrm` or `smb`. Using `smb` is "\
                              "recommended for large file transfers.",
        "host"            => "Host name.",
        "interpreters"    => "A map of an extension name to the absolute path of an executable, "\
                              "enabling you to override the shebang defined in a task executable. The "\
                              "extension can optionally be specified with the `.` character (`.py` and "\
                              "`py` both map to a task executable `task.py`) and the extension is case "\
                              "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                              "Bolt Ruby interpreter by default.",
        "password"        => "Login password. **Required unless using Kerberos.**",
        "port"            => "Connection port.",
        "realm"           => "Kerberos realm (Active Directory domain) to authenticate against.",
        "smb-port"        => "With file-protocol set to smb, this is the port to establish a connection on.",
        "ssl"             => "When true, Bolt uses secure https connections for WinRM.",
        "ssl-verify"      => "When true, verifies the targets certificate matches the cacert.",
        "tmpdir"          => "The directory to upload and execute temporary files on the target.",
        "user"            => "Login user. **Required unless using Kerberos.**"
      }.freeze

      DEFAULTS = {
        "connect-timeout" => 10,
        "ssl"             => true,
        "ssl-verify"      => true,
        "file-protocol"   => "winrm"
      }.freeze

      private def validate
        validate_boolean('ssl', 'ssl-verify')
        validate_type(String, 'cacert', 'file-protocol', 'host', 'password', 'realm', 'tmpdir', 'user')
        validate_type(Integer, 'connect-timeout')
        validate_type(Hash, 'interpreters')
        validate_type(Array, 'extensions')

        ssl_flag = config['ssl']
        if ssl_flag && (config['file-protocol'] == 'smb')
          raise Bolt::ValidationError, "SMB file transfers are not allowed with SSL enabled"
        end

        if ssl_flag && config['cacert']
          @config['cacert'] = File.expand_path(config['cacert'], @boltdir)
          Bolt::Util.validate_file('cacert', config['cacert'])
        end

        if config['interpreters']
          @config['interpreters'] = normalize_interpreters(config['interpreters'])
        end
      end
    end
  end
end
