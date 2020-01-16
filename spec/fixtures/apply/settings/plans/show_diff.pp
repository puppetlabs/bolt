plan settings::show_diff(
  TargetSpec $targets
) {
  $targets.apply_prep

  apply($targets) {
    file { '/root/settings/':
      ensure => directory,
    } -> file { '/root/settings/show_diff.txt':
        ensure  => file,
        content => "Silly string",
    }
  }

  return apply($targets) {
    file { '/root/settings/':
      ensure => directory,
    } -> file { '/root/settings/show_diff.txt':
        ensure  => file,
        content => "Silly string (get it?)",
    }
  }
}
