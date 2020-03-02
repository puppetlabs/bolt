# frozen_string_literal: true

require 'bolt/error'
require 'bolt/config/transport'

module Bolt
  class Config
    class WinRM < Transport
      OPTIONS = {
        "cacert"          => { type: String,
                               desc: "The path to the CA certificate." },
        "connect-timeout" => { type: Integer,
                               desc: "How long Bolt should wait when establishing connections." },
        "extensions"      => { type: Array,
                               desc: "List of file extensions that are accepted for scripts or tasks. "\
                                     "Scripts with these file extensions rely on the target's file type "\
                                     "association to run. For example, if Python is installed on the system, "\
                                     "a `.py` script runs with `python.exe`. The extensions `.ps1`, `.rb`, and "\
                                     "`.pp` are always allowed and run via hard-coded executables." },
        "file-protocol"   => { type: String,
                               desc: "Which file transfer protocol to use. Either `winrm` or `smb`. Using `smb` is "\
                                     "recommended for large file transfers." },
        "host"            => { type: String,
                               desc: "Host name." },
        "interpreters"    => { type: Hash,
                               desc: "A map of an extension name to the absolute path of an executable, "\
                                     "enabling you to override the shebang defined in a task executable. The "\
                                     "extension can optionally be specified with the `.` character (`.py` and "\
                                     "`py` both map to a task executable `task.py`) and the extension is case "\
                                     "sensitive. When a target's name is `localhost`, Ruby tasks run with the "\
                                     "Bolt Ruby interpreter by default." },
        "password"        => { type: String,
                               desc: "Login password. **Required unless using Kerberos.**" },
        "port"            => { type: Integer,
                               desc: "Connection port." },
        "realm"           => { type: String,
                               desc: "Kerberos realm (Active Directory domain) to authenticate against." },
        "smb-port"        => { type: Integer,
                               desc: "With file-protocol set to smb, this is the port to establish a connection on." },
        "ssl"             => { desc: "When true, Bolt uses secure https connections for WinRM." },
        "ssl-verify"      => { desc: "When true, verifies the targets certificate matches the cacert." },
        "tmpdir"          => { type: String,
                               desc: "The directory to upload and execute temporary files on the target." },
        "user"            => { type: String,
                               desc: "Login user. **Required unless using Kerberos.**" }
      }.freeze

      DEFAULTS = {
        "connect-timeout" => 10,
        "ssl"             => true,
        "ssl-verify"      => true,
        "file-protocol"   => "winrm"
      }.freeze

      private def validate
        assert_boolean('ssl', 'ssl-verify')

        assert_type

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
