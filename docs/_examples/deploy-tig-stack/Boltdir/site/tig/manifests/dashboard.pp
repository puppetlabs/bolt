class tig::dashboard (
  String $grafana_password = $tig::params::grafana_password,
  String $grafana_user = $tig::params::grafana_user,
  String $grafana_url = $tig::params::grafana_url,
  String $influx_password = $tig::params::influxdb_password,
  String $influx_database = $tig::params::influxdb_database,
  String $influx_username = $tig::params::influxdb_user,

) inherits ::tig::params {
  class { 'grafana':
    cfg => {
      app_mode => 'production',
      server   => {
        http_port     => 8080,
      },
      security => {
        admin_user => $grafana_user,
        admin_password => $grafana_password,
      },
      database => {
        type          => 'sqlite3',
        host          => '127.0.0.1:3306',
        name          => 'grafananana',
      },
    },
  }

  class {'influxdb': }
  influx_database{$influx_database:
    superuser => $influx_username,
    superpass => $influx_password
  }

  grafana_datasource { 'influxdb':
    require           => Influx_database['bolt'],
    grafana_url       => $grafana_url,
    grafana_user      => $grafana_user,
    grafana_password  => $grafana_password,
    type              => 'influxdb',
    url               => 'http://localhost:8086',
    user              => $influx_username,
    password          => $influx_password,
    database          => $influx_database,
    access_mode       => 'proxy',
    is_default        => true,
  }

  grafana_dashboard { 'telegraf':
    grafana_url       => $grafana_url,
    grafana_user      => $grafana_user,
    grafana_password  => $grafana_password,
    content           => template('tig/dashboards/telegraf.json')
  }
}
