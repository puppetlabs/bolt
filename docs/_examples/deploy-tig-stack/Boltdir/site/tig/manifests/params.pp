class tig::params (
  String $influxdb_password,
  String $grafana_password,
  String $influxdb_database = 'bolt',
  String $influxdb_user = 'bolt',
  String $grafana_url = 'http://localhost:8080',
  String $grafana_user = 'bolt',
) {}
