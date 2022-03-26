# Class: rsync::server
#
# The rsync server. Supports both standard rsync as well as rsync over ssh
#
# Requires:
#   class xinetd if use_xinetd is set to true
#   class rsync
#
class rsync::server(
  $use_xinetd = true,
  $address    = '0.0.0.0',
  $motd_file  = 'UNSET',
  Variant[Enum['UNSET'], Stdlib::Absolutepath] $pid_file = '/var/run/rsyncd.pid',
  $use_chroot = 'yes',
  $uid        = 'nobody',
  $gid        = 'nobody',
  $modules    = {},
  Optional[String[1]] $conf_file = undef,
  Optional[String[1]] $servicename = undef,
) inherits rsync {

  if !$conf_file and !$servicename {
    case $facts['os']['family'] {
      'Debian': {
        $node_conf_file = '/etc/rsyncd.conf'
        $node_servicename = 'rsync'
      }
      'Suse': {
        $node_conf_file = '/etc/rsyncd.conf'
        $node_servicename = 'rsyncd'
      }
      'RedHat': {
        $node_conf_file = '/etc/rsyncd.conf'
        $node_servicename = 'rsyncd'
      }
      'FreeBSD': {
        $node_conf_file = '/usr/local/etc/rsync/rsyncd.conf'
        $node_servicename = 'rsyncd'
      }
      'Archlinux': {
        $node_conf_file = '/etc/rsyncd.conf'
        $node_servicename = 'rsyncd'
      }
      default: {
        $node_conf_file = '/etc/rsync.conf'
        $node_servicename = 'rsync'
      }
    }
  } elsif $conf_file and $servicename{
    $node_conf_file = $conf_file
    $node_servicename = $servicename
  } else {
    fail('Either both or none of conf_file and servicename must be set')
  }

  if $use_xinetd {
    include xinetd
    xinetd::service { 'rsync':
      bind        => $address,
      port        => '873',
      server      => '/usr/bin/rsync',
      server_args => "--daemon --config ${node_conf_file}",
      require     => Package['rsync'],
    }
  } else {
    if ($facts['os']['family'] == 'RedHat') and
        (Integer($facts['os']['release']['major']) >= 8) and
        ($rsync::manage_package) {
      package { 'rsync-daemon':
        ensure => $rsync::package_ensure,
        notify => Service[$node_servicename],
      }
    }

    service { $node_servicename:
      ensure     => running,
      enable     => true,
      hasstatus  => true,
      hasrestart => true,
      subscribe  => Concat[$node_conf_file],
    }

    if ( $facts['os']['family'] == 'Debian' ) {
      file { '/etc/default/rsync':
        source => 'puppet:///modules/rsync/defaults',
        notify => Service['rsync'],
      }
    }
  }

  if $motd_file != 'UNSET' {
    file { '/etc/rsync-motd':
      source => 'puppet:///modules/rsync/motd',
    }
  }

  concat { $node_conf_file: }

  # Template uses:
  # - $use_chroot
  # - $address
  # - $motd_file
  concat::fragment { 'rsyncd_conf_header':
    target  => $node_conf_file,
    content => template('rsync/header.erb'),
    order   => '00_header',
  }

  create_resources(rsync::server::module, $modules)

}
