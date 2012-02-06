# Author: Kumina bv <support@kumina.nl>

# Class: kbp_apache
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_apache_new {
  include gen_apache
  include kbp_munin::client::apache

  kfile {
    "/etc/apache2/mods-available/deflate.conf":
      source  => "kbp_apache_new/mods-available/deflate.conf",
      require => Package["apache2"],
      notify  => Exec["reload-apache2"];
    "/etc/apache2/conf.d/security":
      source  => "kbp_apache_new/conf.d/security",
      require => Package["apache2"],
      notify  => Exec["reload-apache2"];
    "/srv/www":
      ensure => directory;
  }

  gen_logrotate::rotate { "apache2":
    logs       => "/var/log/apache2/*.log",
    options    => ["weekly", "rotate 52", "missingok", "notifempty", "create 640 root adm", "compress", "delaycompress", "sharedscripts", "dateext"],
    postrotate => "/etc/init.d/apache2 reload > /dev/null",
    require    => Package["apache2"];
  }

  kbp_apache_new::module { ["deflate","rewrite"]:; }

  kbp_monitoring::http { "http_${fqdn}":; }
}

# Class: kbp_apache::passenger
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_apache_new::passenger {
  include kbp_apache_new
  include gen_base::libapache2-mod-passenger
  include kbp_apache_new::module::passenger
  include kbp_monitoring::passenger::queue
}

class kbp_apache_new::php {
  include gen_base::libapache2-mod-php5
}

# Class: kbp_apache::ssl
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_apache_new::ssl {
  kfile { "/etc/apache2/ssl":
    ensure  => directory,
    require => Package["apache2"];
  }

  gen_ferm::rule { "HTTPS connections":
    proto  => "tcp",
    dport  => "443",
    action => "ACCEPT";
  }

  kbp_apache_new::module { "ssl":; }
}

# Class: kbp_apache::module::passenger
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_apache_new::module::passenger {
  kbp_apache_new::module { "passenger":
    require => Kpackage["libapache2-mod-passenger"];
  }
}

class kbp_apache_new::module::dav {
  kbp_apache_new::module { "dav":; }
}

class kbp_apache_new::module::dav_fs {
  kbp_apache_new::module { "dav_fs":; }
}

class kbp_apache_new::module::auth_mysql {
  kbp_apache_new::module { "auth_mysql":; }
}

define kbp_apache_new::cgi($documentroot) {
  include gen_base::libapache2-mod-fcgid

  kfile { "/etc/apache2/vhost-additions/${name}/enable-cgi":
    content => template("kbp_apache_new/vhost-additions/enable_cgi"),
    notify  => Exec["reload-apache2"];
  }
}

class kbp_apache_new::module::jk {
  include gen_apache::jk
}

class kbp_apache_new::module::headers {
  kbp_apache_new::module { "headers":; }
}

class kbp_apache_new::intermediate::rapidssl {
  kbp_ssl::public_key { "RapidSSL_CA_bundle":
    source => "kbp_apache_new/ssl/RapidSSL_CA_bundle.pem",
    notify => Exec["reload-apache2"];
  }
}

class kbp_apache_new::intermediate::positivessl {
  kbp_ssl::public_key { "PositiveSSLCA":
    source => "kbp_apache_new/ssl/PositiveSSLCA.pem",
    notify => Exec["reload-apache2"];
  }
}

class kbp_apache_new::glassfish_domain_base {
  include kbp_apache_new::module::jk

  concat { "/etc/apache2/workers.properties":
    require => Package["apache2"];
  }

  concat::add_content {
    "0 worker base":
      content   => "worker.list=",
      linebreak => false,
      target    => "/etc/apache2/workers.properties";
    "2 worker base":
      content => "",
      target  => "/etc/apache2/workers.properties";
  }

  kfile { "/etc/apache2/conf.d/jk":
    content => template("kbp_apache_new/conf.d/jk");
  }
}

define kbp_apache_new::php_cgi($documentroot) {
  include gen_base::php5-cgi
  include gen_base::php-apc

  kbp_apache_new::cgi { $name:
    documentroot => $documentroot;
  }

  Package <| title == "gen_base::libapache2-mod-php5" |> {
    ensure => purged,
    notify => Exec["reload-apache2"],
  }
}

# Define: kbp_apache::site
#
# Parameters:
#  priority
#    Undocumented
#  ensure
#    Undocumented
#  max_check_attempts
#    For overriding the default max_check_attempts of the service
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_apache_new::site($ensure="present", $serveralias=false, $documentroot=false, $create_documentroot=true, $address=false, $address6=false,
    $port=false, $make_default=false, $ssl=false, $key=false, $cert=false, $intermediate=false, $wildcard=false,
    $redirect_non_ssl=true, $auth=false, $max_check_attempts=false, $monitor_path=false, $monitor_response=false, $monitor_probe=false,
    $monitor=true, $smokeping=true, $php=false, $glassfish_domain=false, $glassfish_connector_port=false, $django_root_path=false,
    $django_root_django=false, $django_static_path=false, $django_static_django=false) {
  include kbp_apache_new
  if $key or $cert or $intermediate or $wildcard or $ssl {
    include kbp_apache_new::ssl

    $real_ssl = true
  } else {
    $real_ssl = false
  }

  $temp_name   = $port ? {
    false   => $name,
    default => "${name}_${port}",
  }
  if $real_ssl {
    $full_name = regsubst($temp_name,'^([^_]*)$','\1_443')
  } else {
    $full_name = regsubst($temp_name,'^([^_]*)$','\1_80')
  }
  $real_name   = regsubst($full_name,'^(.*)_(.*)$','\1')
  $real_port   = regsubst($full_name,'^(.*)_(.*)$','\2')
  $dontmonitor = ["default","default-ssl","localhost"]
  $real_documentroot = $documentroot ? {
    false   => "/srv/www/${real_name}",
    default => $documentroot,
  }

  gen_apache::site { $full_name:
    ensure           => $ensure,
    serveralias      => $serveralias,
    documentroot     => $real_documentroot,
    address          => $address,
    address6         => $address6,
    port             => $port,
    make_default     => $make_default,
    ssl              => $ssl,
    key              => $key,
    cert             => $cert,
    intermediate     => $intermediate,
    wildcard         => $wildcard;
  }

  if $ensure == "present" and $monitor and ! ($name in $dontmonitor) {
    if $real_ssl {
      $monitor_name             = "${real_name}_SSL"
      $real_service_description = "Vhost ${real_name} SSL"

      if ! $wildcard {
        kbp_monitoring::sslcert { $real_name:; }
      }

      if $redirect_non_ssl {
        kbp_apache_new::forward_vhost { $real_name:
          ensure      => $ensure,
          forward     => "https://${real_name}",
          serveralias => $serveralias;
        }
      }
    } else {
      $monitor_name             = $real_name
      $real_service_description = "Vhost ${real_name}"
    }

    kbp_monitoring::site { $monitor_name:
      service_description => $real_service_description,
      host_name           => $real_name,
      max_check_attempts  => $max_check_attempts,
      auth                => $auth,
      path                => $monitor_path,
      response            => $monitor_response,
      ssl                 => $real_ssl;
    }

    if $smokeping {
      kbp_smokeping::target { $name:
        probe => $monitor_probe ? {
          false   => $auth ? {
            false => undef,
            true  => "FPing",
          },
          default => $monitor_probe,
        },
        path  => $monitor_path;
      }
    }
  }

  if ! defined(Gen_ferm::Rule["HTTP connections on ${real_port}"]) {
    gen_ferm::rule { "HTTP connections on ${real_port}":
      proto  => "tcp",
      dport  => $real_port,
      action => "ACCEPT";
    }
  }

  if $glassfish_domain {
    if ! $glassfish_connector_port {
      fail { "glassfish_connector_port is undefined for ${site}":; }
    }

    kbp_apache_new::glassfish_domain { $glassfish_domain:
      site           => $real_name,
      site_port      => $real_port,
      connector_port => $glassfish_connector_port;
    }
  }

  if $django_root_path or $django_root_django or $django_static_path or $django_static_django {
    include kbp_django

    if ! $django_root_path {
      fail("${fullname} is defined as a Django site but \$django_root_path has not been set")
    }
    if ! $django_root_django {
      fail("${fullname} is defined as a Django site but \$django_root_django has not been set")
    }
    if ! $django_static_path {
      fail("${fullname} is defined as a Django site but \$django_static_path has not been set")
    }
    if ! $django_static_django {
      fail("${fullname} is defined as a Django site but \$django_static_django has not been set")
    }
    kbp_apache_new::vhost_addition { "${full_name}/django":
      content => template("kbp_apache_new/vhost-additions/django")
    }
  }

  if $php {
    kbp_apache_new::php_cgi { $full_name:
      documentroot => $real_documentroot;
    }
  }
}

define kbp_apache_new::module {
  gen_apache::module { $name:; }
}

define kbp_apache_new::forward_vhost ($forward, $ensure="present", $serveralias=false, $statuscode=301) {
  gen_apache::forward_vhost { $name:
    forward     => $forward,
    ensure      => $ensure,
    serveralias => $serveralias,
    statuscode  => $statuscode;
  }

  kbp_monitoring::site { "${name}_forward":
    service_description => "Vhost ${name} forward",
    host_name           => $name,
    statuscode          => $statuscode,
    response            => $forward;
  }
}

define kbp_apache_new::vhost_addition($ensure="present", $content=false, $source=false) {
  $fullname = regsubst($name,'^(.*?)_.*$','\1')
  $port     = regsubst($name,'^.*_(.*?)/.*$','\1')

  if defined(Kbp_apache_new::Forward_vhost[$fullname]) and $port == 80 {
    fail("kbp_apache_new::vhost_addition ${name} is inconsistent as a forward is in place for this site.")
  }

  gen_apache::vhost_addition { $name:
    ensure  => $ensure,
    content => $content,
    source  => $source;
  }
}

define kbp_apache_new::glassfish_domain($site, $site_port, $connector_port) {
  include kbp_apache_new::glassfish_domain_base

  kbp_apache_new::vhost_addition { "${site}_${site_port}/glassfish-jk":
    content => "JkMount /* ${name}";
  }

  concat::add_content {
    "1 worker domain ${name}":
      content   => "${name},",
      linebreak => false,
      target    => "/etc/apache2/workers.properties";
    "3 worker domain ${name} settings":
      content => template("kbp_apache_new/glassfish/workers.properties_settings"),
      target  => "/etc/apache2/workers.properties";
  }
}
