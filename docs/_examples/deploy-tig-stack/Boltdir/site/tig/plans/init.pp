plan tig() {

  apply_prep('all')

  apply('dashboard') {
    include tig::dashboard
  }

  $dashboard_host = get_targets('dashboard')[0].name

  apply('agents') {
    class{ tig::telegraf:
      influx_host => $dashboard_host
    }
  }

  return('grafana_dashboard' => "http://${dashboard_host}:8080")
}
