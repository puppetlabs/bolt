plan example_apply (
  TargetSpec $targets,
  String $filepath,
  Boolean $noop = false,
  Optional[String] $run_as = undef,
) {
  $targets.apply_prep

  return apply($targets, _noop => $noop, _run_as => $run_as, _catch_errors => true) {
    file { $filepath:
      ensure => directory,
    } -> file { "${filepath}/hello.txt":
      ensure  => file,
      content => "hi ${::myfact} ${::another} ${$facts['os']['family']}\n",
    }

    warn { 'Writing a MOTD!':
    } -> file { "${filepath}/motd":
      ensure => file,
      source => 'puppet:///modules/example_apply/motd',
    }
  }
}
