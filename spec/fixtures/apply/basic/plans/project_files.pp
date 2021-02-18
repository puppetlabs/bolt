plan basic::project_files (
  TargetSpec $targets,
  String     $project_name
) {
  $result = apply($targets) {
    file { '/test.txt':
      source => "puppet:///modules/${project_name}/testfile"
    }
  }

  apply($targets) {
    file { '/test.txt':
      ensure => absent
    }
  }

  return $result
}
