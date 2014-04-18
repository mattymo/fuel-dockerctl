$fuel_settings = parseyaml($astute_settings_yaml)

# this replaces removed postgresql version fact
$postgres_default_version = '8.4'


node default {

  Exec  {path => '/usr/bin:/bin:/usr/sbin:/sbin'}

  Class['nailgun::packages'] ->
  Class['nailgun::ostf'] ->
  Class['nailgun::supervisor']

  class { "nailgun::packages": }

  class { "nailgun::ostf":
    production => "docker-build",
    pip_opts   => "${pip_index} ${pip_find_links}",
    dbuser     => 'ostf',
    dbpass     => 'ostf',
    dbhost     => $::fuel_settings['ADMIN_NETWORK']['ipaddress'],
    dbport     => '5432',
    host       => "0.0.0.0",
  }
  class { "nailgun::supervisor":
    venv      => '/opt/fuel_plugins/ostf',
    conf_file => "nailgun/supervisord.conf.ostf.erb",
  }

}

