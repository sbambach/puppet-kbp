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

  file {
    "/etc/apache2/mods-available/deflate.conf":
      content => template("kbp_apache_new/mods-available/deflate.conf"),
      require => Package["apache2"],
      notify  => Exec["reload-apache2"];
    "/etc/apache2/conf.d/security":
      content => template("kbp_apache_new/conf.d/security"),
      require => Package["apache2"],
      notify  => Exec["reload-apache2"];
  }

  # There are classes that override /srv/www (think the NFS class), this makes sure
  # that will work.
  if ! defined(File["/srv/www"]) {
    file { "/srv/www":
      ensure => directory;
    }
  }

  gen_logrotate::rotate { "apache2":
    logs       => "/var/log/apache2/*.log",
    options    => ["weekly", "rotate 52", "missingok", "notifempty", "create 640 root adm", "compress", "delaycompress", "sharedscripts", "dateext"],
    postrotate => "/etc/init.d/apache2 reload > /dev/null",
    require    => Package["apache2"];
  }

  kbp_apache_new::module { ["deflate","rewrite"]:; }

  kbp_icinga::http { "http_${fqdn}":; }
}

# Class: kbp_apache_new::global_umask_007
#
# Actions:
#  Set the umask of the Apache process to 007, for broken scripts that otherwise create files
#  world-readable/writable.
#
# Depends:
#  kbp_apache_new
#
class kbp_apache_new::global_umask_007 {
  line { "Set Apache's umask":
    file    => "/etc/apache2/envvars",
    content => "umask 007",
    require => Package["apache2"]
  }
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
  include kbp_icinga::passenger::queue
}

class kbp_apache_new::php {
  include gen_base::libapache2_mod_php5
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
    require => Package["libapache2-mod-passenger"];
  }
}

class kbp_apache_new::module::expires {
  kbp_apache_new::module { "expires":; }
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

class kbp_apache_new::module::proxy_http {
  kbp_apache_new::module { "proxy_http":
    notify => Exec["force-reload-apache2"];
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
    content => template("kbp_apache_new/ssl/RapidSSL_CA_bundle.pem"),
    notify  => Exec["reload-apache2"];
  }
}

class kbp_apache_new::intermediate::positivessl {
  kbp_ssl::public_key { "PositiveSSLCA":
    content => template("kbp_apache_new/ssl/PositiveSSLCA.pem"),
    notify  => Exec["reload-apache2"];
  }
}

class kbp_apache_new::intermediate::thawte {
  kbp_ssl::public_key { "Thawte_SSL_CA":
    content => template("kbp_apache_new/ssl/Thawte_SSL_CA.pem"),
    notify  => Exec["reload-apache2"];
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

  file { "/etc/apache2/conf.d/jk":
    content => template("kbp_apache_new/conf.d/jk");
  }
}

define kbp_apache_new::php_cgi($ensure="present", $documentroot, $custom_php_ini=false) {
  if $ensure == "present" {
    include gen_php5::cgi
    include gen_php5::apc
    include gen_base::apache2_mpm_worker

    kbp_apache_new::cgi { $name:
      documentroot   => $documentroot,
      custom_php_ini => $custom_php_ini;
    }

    Package <| title == "libapache2-mod-php5" |> {
      ensure => purged,
      notify => Exec["force-reload-apache2"],
    }
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
#  log_vhost
#    If set to true, it logs the serveralias from the request in the access log
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_apache_new::site($ensure="present", $serveralias=false, $documentroot=false, $create_documentroot=true, $address=false, $address6=false,
    $port=false, $make_default=false, $ssl=false, $key=false, $cert=false, $intermediate=false, $wildcard=false, $log_vhost=false, $access_logformat="combined",
    $redirect_non_ssl=true, $auth=false, $max_check_attempts=false, $monitor_path=false, $monitor_response=false, $monitor_probe=false, $monitor_creds=false,
    $monitor_check_interval=false,$monitor=true, $smokeping=true, $php=false, $custom_php_ini=false, $glassfish_domain=false, $glassfish_connector_port=false,
    $django_root_path=false,$django_root_django=false, $django_static_path=false, $django_static_django=false, $django_settings=false) {
  include kbp_apache_new

  $temp_name   = $port ? {
    false   => $name,
    default => "${name}_${port}",
  }
  if $key or $cert or $intermediate or $wildcard or $ssl {
    if ! $address and ! $address6 and ! $wildcard {
      fail("Kbp_apache_new::site(${name}) is an SSL site but no IP address has been set.")
    }

    include kbp_apache_new::ssl

    $real_ssl = true
    $full_name = regsubst($temp_name,'^([^_]*)$','\1_443')
  } else {
    $real_ssl = false
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
    ensure              => $ensure,
    serveralias         => $serveralias,
    create_documentroot => $create_documentroot,
    documentroot        => $real_documentroot,
    address             => $address,
    address6            => $address6,
    port                => $port,
    log_vhost           => $log_vhost,
    access_logformat    => $access_logformat,
    make_default        => $make_default,
    ssl                 => $ssl,
    key                 => $key,
    cert                => $cert,
    intermediate        => $intermediate,
    wildcard            => $wildcard;
  }

  if $ensure == "present" and $monitor and ! ($name in $dontmonitor) {
    if $real_ssl {
      $monitor_name = "${real_name}_SSL"

      if ! $wildcard {
        kbp_icinga::sslcert { $real_name:; }
      }

      if $redirect_non_ssl {
        kbp_apache_new::forward_vhost { $real_name:
          ensure      => $ensure,
          forward     => "https://${real_name}",
          serveralias => $serveralias;
        }
      }
    } else {
      $monitor_name = $real_name
    }

    kbp_icinga::site { $monitor_name:
      service_description => $service_description,
      address             => $address,
      address6            => $address6,
      host_name           => $real_name,
      max_check_attempts  => $max_check_attempts,
      auth                => $auth,
      path                => $monitor_path,
      response            => $monitor_response,
      credentials         => $monitor_creds,
      check_interval      => $monitor_check_interval,
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

  if ! defined(Gen_ferm::Rule["HTTP(S) connections on ${real_port}"]) {
    gen_ferm::rule { "HTTP(S) connections on ${real_port}":
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

  if $django_settings {
    include kbp_django

    $real_django_root_path = $django_root_path ? {
      false   => '/',
      default => $django_root_path,
    }
    $real_django_root_django = $django_root_django ? {
      false   => "/${real_name}",
      default => $django_root_django,
    }
    $real_django_static_path = $django_static_path ? {
      false   => '/media',
      default => $django_static_path,
    }
    $real_django_static_django = $django_static_django ? {
      false   => "/${real_name}/media",
      default => $django_static_django,
    }

    kbp_apache_new::vhost_addition { "${full_name}/django":
      content => template("kbp_apache_new/vhost-additions/django");
    }

    file {
      "/srv/django${real_django_root_django}":
        ensure  => directory;
      "/srv/django${real_django_root_django}/dispatch.wsgi":
        content => template("kbp_apache_new/django/dispatch.wsgi"),
        replace => false,
        mode    => 755;
      "/srv/django${real_django_static_django}":
        ensure  => directory;
    }
  }

  if $php {
    case $php {
      # Mod_php, I choose you!
      'mod_php': {
        include kbp_apache_new::php
      }
      # Default to CGI
      default:   {
        kbp_apache_new::php_cgi { $full_name:
          documentroot   => $real_documentroot,
          custom_php_ini => $custom_php_ini;
        }
      }
    }
  }
}

define kbp_apache_new::module ($ensure = "enable") {
  gen_apache::module { $name:
    ensure => $ensure;
  }
}

define kbp_apache_new::forward_vhost ($forward, $ensure="present", $serveralias=false, $statuscode=301, $port=80) {
  gen_apache::forward_vhost { $name:
    forward     => $forward,
    ensure      => $ensure,
    serveralias => $serveralias,
    statuscode  => $statuscode,
    port        => $port;
  }

  kbp_icinga::site { "${name}_forward":
    service_description => "Vhost ${name} forward",
    host_name           => $name,
    statuscode          => $statuscode,
    response            => $forward;
  }

  if ! defined(Gen_ferm::Rule["HTTP(S) connections on ${port}"]) {
    gen_ferm::rule { "HTTP(S) connections on ${port}":
      proto  => "tcp",
      dport  => $port,
      action => "ACCEPT";
    }
  }
}

define kbp_apache_new::vhost_addition($ensure="present", $content=false) {
  $fullname = regsubst($name,'^(.*?)_.*$','\1')
  $port     = regsubst($name,'^.*_(.*?)/.*$','\1')

  if defined(Kbp_apache_new::Forward_vhost[$fullname]) and $port == 80 {
    fail("kbp_apache_new::vhost_addition ${name} is inconsistent as a forward is in place for this site.")
  }

  gen_apache::vhost_addition { $name:
    ensure  => $ensure,
    content => $content ? {
      false   => undef,
      default => $content,
    };
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

define kbp_apache_new::cgi($documentroot, $custom_php_ini=false) {
  include gen_base::libapache2-mod-fcgid

  kbp_apache_new::vhost_addition { "${name}/enable-cgi":
    content => template("kbp_apache_new/vhost-additions/enable_cgi");
  }
}
