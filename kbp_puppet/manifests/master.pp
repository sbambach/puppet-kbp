# Author: Kumina bv <support@kumina.nl>

# Class: kbp_puppet::master
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_puppet::master {
  include gen_puppet::master
  include kbp_puppet::vim
  include kbp_rails::mysql
  include kbp_apache::passenger
  include kbp_trending::puppetmaster
  # TODO once this uses the new apache modules this can be removed
  include kbp_icinga::passenger::queue

  gen_apt::preference { ["puppetmaster","puppetmaster-common"]:; }

  @package { "puppetstoredconfigcleanhenker":
    ensure => latest;
  }

  # Enforce Puppet modules directory permissions.
  file {
    "/srv/puppet":
      ensure  => directory,
      owner   => "puppet",
      mode    => 2770,
      require => Package["puppetmaster"];
    "/srv/puppet/env":
      ensure  => directory,
      owner   => "puppet",
      mode    => 2770,
      require => Package["puppetmaster"];
    "/srv/puppet/generic":
      ensure  => directory,
      owner   => "puppet",
      mode    => 2770,
      require => Package["puppetmaster"];
    "/srv/puppet/kbp":
      ensure  => directory,
      owner   => "puppet",
      mode    => 2770,
      require => Package["puppetmaster"];
  }

  # Enforce ownership and permissions
  setfacl {
    "Directory permissions in /srv/puppet for group root":
      dir     => "/srv/puppet",
      acl     => "default:group:root:rwx",
      require => File["/srv/puppet"];
    "Directory permissions in /srv/puppet for user puppet":
      dir     => "/srv/puppet",
      acl     => "default:user:puppet:r-x",
      require => File["/srv/puppet"];
    "Directory permissions in /srv/puppet/env for group root":
      dir     => "/srv/puppet/env",
      acl     => "default:group:root:rwx",
      require => File["/srv/puppet/env"];
    "Directory permissions in /srv/puppet/env for user puppet":
      dir     => "/srv/puppet/env",
      acl     => "default:user:puppet:r-x",
      require => File["/srv/puppet/env"];
    "Directory permissions in /srv/puppet/generic for group root":
      dir     => "/srv/puppet/generic",
      acl     => "default:group:root:rwx",
      require => File["/srv/puppet/generic"];
    "Directory permissions in /srv/puppet/generic for user puppet":
      dir     => "/srv/puppet/generic",
      acl     => "default:user:puppet:r-x",
      require => File["/srv/puppet/generic"];
    "Directory permissions in /srv/puppet/kbp for group root":
      dir     => "/srv/puppet/kbp",
      acl     => "default:group:root:rwx",
      require => File["/srv/puppet/kbp"];
    "Directory permissions in /srv/puppet/kbp for user puppet":
      dir     => "/srv/puppet/kbp",
      acl     => "default:user:puppet:r-x",
      require => File["/srv/puppet/kbp"];
  }

  kbp_git::repo {
    "/srv/puppet/generic":
      origin => "git@github.com:kumina/puppet-generic.git";
    "/srv/puppet/kbp":
      origin => "git@github.com:kumina/puppet-kbp.git";
  }

  kbp_dashboard::service::wrapper { 'puppetmaster':
    fullname => 'Puppetmaster';
  }
}

# Define: kbp_puppet::master::config
#
# Parameters:
#  configfile
#    Undocumented
#  debug
#    Undocumented
#  caserver
#    Undocumented
#
# Actions:
#  Setup a puppetmaster in the Kumina way, using Apache and passenger.
#  Allows for multiple puppetmasters with (mostly) different configs.
#  Keep in mind that if you want default puppetmaster (which is
#  probably most of the time), you just need to name it "default" and
#  most settings will be indeed default.
#
# Depends:
#  kbp_puppet::master
#  gen_puppet
#
define kbp_puppet::master::config ($caserver = false, $configfile = "/etc/puppet/puppet.conf", $debug = false,
        $dbsetup = true, $dbname = false, $dbuser = false, $dbpasswd = false,
        $dbhost = false, $dbserver = false, $dbsocket = false, $environments = [],
        $factpath = '$vardir/lib/facter', $logdir = "/var/log/puppet",
        $pluginsync = true, $port = "8140", $queue = false, $queue_host = "localhost",
        $queue_port = "61613", $rackroot = "/usr/local/share/puppet/rack",
        $rundir = "/var/run/puppet", $ssldir = "/var/lib/puppet/ssl",
        $templatedir = '$confdir/templates', $vardir = "/var/lib/puppet") {

  include apache

  # The dbhost config option changed into dbserver somewhere in 2.6-2.7, we
  # accept both for now. Maybe give a message at some point.
  if $dbserver { $set_dbserver = $dbserver }
  else         { $set_dbserver = $dbhost   }

  # If the name is 'default', we want to change the puppetmaster name (pname)
  # we're using for this instance to something without crud.
  if $name == 'default' {
    $pname = 'puppetmaster'
  } else {
    $sanitized_name = regsubst($name, '[^a-zA-Z0-9\-_]', '_', 'G')
    $pname = "puppetmaster-${sanitized_name}"
  }

  # Check if we need a db or not
  if $name == "caserver" { $real_dbsetup = false    }
  else                   { $real_dbsetup = $dbsetup }

  # The rackdir that is being used
  $rackdir = "${rackroot}/${pname}"

  # The address to bind to
  $address = "*:${port}"

  gen_puppet::master::config { $name:
    configfile  => $configfile,
    debug       => $debug,
    factpath    => $factpath,
    logdir      => $logdir,
    pluginsync  => $pluginsync,
    queue       => $queue,
    rackroot    => $rackroot,
    rundir      => $rundir,
    ssldir      => $ssldir,
    templatedir => $templatedir,
    vardir      => $vardir,
  }

  # The apache config should determine where to listen on
  apache::site_config { "${pname}":
    address      => $address,
    documentroot => "${rackdir}/public",
    template     => "apache/sites-available/simple-fqdn.erb",
  }

  # Open the port in Apache
  line { "Make Apache listen to port ${port} for puppetmaster ${name}.":
    content => "Listen ${port}",
    file    => "/etc/apache2/ports.conf",
    require => Package["apache2"],
  }

  # Open the firewall for our puppetmaster
  kbp_ferm::rule { "Connections to puppetmaster ${name}.":
    proto  => "tcp",
    dport  => $port,
    action => "ACCEPT",
  }

  # The vhost-addition should set the documentroot, the puppet directory,
  # the additional apache permissions and debugging options.
  file {
    "/etc/apache2/vhost-additions/${pname}/permissions.conf":
      notify  => Exec["reload-apache2"],
      content => template("kbp_puppet/master/apache2/vhost-additions/permissions.conf.erb");
    "/etc/apache2/vhost-additions/${pname}/rack.conf":
      notify  => Exec["reload-apache2"],
      content => template("kbp_puppet/master/apache2/vhost-additions/rack.conf");
    "/etc/apache2/vhost-additions/${pname}/ssl.conf":
      notify  => Exec["reload-apache2"],
      require => File["${ssldir}/ca/ca_crt.pem","${ssldir}/ca/ca_crl.pem"],
      content => template("kbp_puppet/master/apache2/vhost-additions/ssl.conf.erb");
  }

  # Enable the site
  kbp_apache::site { "${pname}":; }

  # Make sure we only setup database stuff when asked for
  if $real_dbsetup {
    include gen_base::libactiverecord_ruby18

    if $name == 'default' {
      $real_dbname = 'puppet'
      $real_dbuser = 'puppet'
      # Yes, we have a default password. That's not problem since MySQL
      # only allows access from restricted hosts.
      $real_dbpasswd = 'puppet'
    } else {
      $real_dbname = $dbname ? {
        false   => regsubst($pname,'-','_','G'),
        default => $dbname,
      }
      $real_dbuser = $dbuser ? {
        # We should make sure this is never longer than 16 chars
        false   => regsubst("pm_${sanitized_name}",'(.{1,16}).*','\1'),
        default => regsubst($dbuser,'(.{1,16}).*','\1'),
      }
      $real_dbpasswd = $dbpasswd ? {
        false   => $pname,
        default => $dbpasswd,
      }
    }

    # Setup the MySQL only if one of the following condition apply:
    # - dbserver is false or localhost (false implies localhost)
    # - dbserver is equal to local fqdn

    if ((! $set_dbserver) or ($set_dbserver == 'localhost')) or ($set_dbserver == $fqdn) {
      mysql::server::db { $real_dbname:; }

      mysql::server::grant { $real_dbname:
        hostname => "localhost",
        user     => $real_dbuser,
        password => $real_dbpasswd,
        db       => $real_dbname;
      }
    } else {
      @@mysql::server::db { $real_dbname:
        tag => "${environment}_puppetmaster";
      }

      @@mysql::server::grant { $real_dbname:
        user     => $real_dbuser,
        password => $real_dbpasswd,
        db       => $real_dbname,
        hostname => "%",
        tag      => "${environment}_puppetmaster";
      }

      kbp_mysql::client { $pname:
        mysql_name => "puppetmaster",
      }
    }

    gen_puppet::set_config {
      "Set database adapter for ${name} in main.":
        configfile => $configfile,
        var        => 'dbadapter',
        value      => 'mysql',
        section    => 'main';
      "Set database user for ${name} in main.":
        configfile => $configfile,
        var        => 'dbuser',
        value      => $real_dbuser,
        section    => 'main';
      "Set database name for ${name} in main.":
        configfile => $configfile,
        var        => 'dbname',
        value      => $real_dbname,
        section    => 'main';
      "Set database password for ${name} in main.":
        configfile => $configfile,
        var        => 'dbpassword',
        value      => $real_dbpasswd,
        section    => 'main';
      "Set storeconfig for ${name}.":
        configfile => $configfile,
        var        => 'storeconfigs',
        value      => 'true',
        section    => 'main',
        require    => Package["libactiverecord-ruby1.8"];
      "Set thin_storeconfigs for ${name}.":
        configfile => $configfile,
        var        => 'thin_storeconfigs',
        value      => 'false',
        section    => 'main';
      "Set dbmigrate for ${name}.":
        configfile => $configfile,
        var        => 'dbmigrate',
        value      => 'true',
        section    => 'main';
    }

    # We need these settings in [main] as well as [master], it seems.
    gen_puppet::set_config {
      "Set database adapter for ${name} in master.":
        configfile => $configfile,
        var        => 'dbadapter',
        value      => 'mysql',
        section    => 'master';
      "Set database user for ${name} in master.":
        configfile => $configfile,
        var        => 'dbuser',
        value      => $real_dbuser,
        section    => 'master';
      "Set database name for ${name} in master.":
        configfile => $configfile,
        var        => 'dbname',
        value      => $real_dbname,
        section    => 'master';
      "Set database password for ${name} in master.":
        configfile => $configfile,
        var        => 'dbpassword',
        value      => $real_dbpasswd,
        section    => 'master';
      "Set storeconfig for ${name} in master.":
        configfile => $configfile,
        var        => 'storeconfigs',
        value      => 'true',
        section    => 'master',
        require    => Package["libactiverecord-ruby1.8"];
      "Set thin_storeconfigs for ${name} in master.":
        configfile => $configfile,
        var        => 'thin_storeconfigs',
        value      => 'false',
        section    => 'master';
      "Set dbmigrate for ${name} in master.":
        configfile => $configfile,
        var        => 'dbmigrate',
        value      => 'true',
        section    => 'master';
    }

    # Only set the host if it's needed.
    if $set_dbserver {
      gen_puppet::set_config {
        "Set database host for ${name}.":
          configfile => $configfile,
          var        => 'dbserver',
          value      => $set_dbserver,
          section    => 'main';
        "Set database host for ${name} in master.":
          configfile => $configfile,
          var        => 'dbserver',
          value      => $set_dbserver,
          section    => 'master';
      }
    }

    # Only set the socket if it's needed.
    if $dbsocket {
      gen_puppet::set_config { "Set database socket for ${name}.":
        configfile => $configfile,
        var        => 'dbsocket',
        value      => $dbsocket,
        section    => 'main',
      }
    }

    # Setup queueing for this puppetmaster.
    # We only setup queueing when we also setup db settings, otherwise
    # queueing makes no sense...
    if $queue {
      if $queue_host == "localhost" {
        include kbp_activemq
      }

      include gen_base::libstomp_ruby

      gen_puppet::set_config {
        "Set async storeconfigs for ${name}.":
          configfile => $configfile,
          var        => 'async_storeconfigs',
          value      => 'true',
          section    => 'master';
        "Set queue type for ${name}.":
          configfile => $configfile,
          var        => 'queue_type',
          value      => 'stomp',
          section    => 'main',
          require    => Package["libstomp-ruby"];
        "Set queue source for ${name}.":
          configfile => $configfile,
          var        => "queue_source",
          value      => "stomp://${queue_host}:${queue_port}",
          section    => 'main';
      }
    }
  }

  # This uses the internal definition.
  kbp_puppet::master::environment { $environments:
    configfile => $configfile,
  }

  # Open the firewall for all hosts, since we use SSL anyway.
  gen_ferm::rule { "HTTP connections for ${pname}":
    proto  => "tcp",
    dport  => $port,
    action => "ACCEPT",
  }
}

# Define: kbp_puppet::master::environment
#
# Parameters:
#  configfile
#    Undocumented
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_puppet::master::environment ($configfile = "/srv/puppet/puppet.conf") {
  include kbp_git

  gen_puppet::master::environment { $name:
    configfile => $configfile,
  }

  kbp_git::repo { "/srv/puppet/env/${name}":; }

  file {
    "/srv/puppet/env/${name}":
      mode    => 775,
      ensure  => directory;
  }
}
