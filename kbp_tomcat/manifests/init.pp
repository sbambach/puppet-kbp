# Author: Kumina bv <support@kumina.nl>

# Class: kbp_tomcat
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_tomcat ($tomcat_tag="tomcat_${environment}", $serveralias=false, $documentroot=false, $ssl=false, $ajp13_connector_port = "8009",
                  $java_opts="", $jvm_max_mem=false){
  include kbp_apache

  class { "gen_tomcat":
    ajp13_connector_port => $ajp13_connector_port,
    java_opts            => $java_opts,
    jvm_max_mem          => $jvm_max_mem;
  }

  # Enable mod-proxy-ajp
  apache::module { "proxy_ajp":
    ensure => present,
  }

  # Add /usr/share/java/*.jar to the tomcat classpath
  kfile { "/srv/tomcat/conf/catalina.properties":
    source  => "kbp_tomcat/catalina.properties",
    require => [Package["tomcat6"], File["/srv/tomcat/conf"]];
  }

  # Ensure that everyone in the group tomcat6 can restart Tomcat
  kbp_sudo::rule { "Allow tomcat manipulation when in the tomcat6 group":
    command           => "/etc/init.d/tomcat6 [a-z]*",
    as_user           => "root",
    entity            => "@tomcat6",
    password_required => false,
  }
}

# Class: kbp_tomcat::mysql
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_tomcat::mysql {
#  include kbp_tomcat
#  include kbp_mysql::client::java
}

# Define: kbp_tomcat::webapp
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_tomcat::webapp($war="", $urlpath="/", $context_xml_content=false, $root_app=false, $tomcat_tag="tomcat_${environment}") {
  gen_tomcat::context { $name:
    tomcat_tag          => $tomcat_tag,
    war                 => $war,
    urlpath             => $urlpath,
    context_xml_content => $context_xml_content,
    root_app            => $root_app;
  }
}

# Define: kbp_tomcat::apache_proxy_ajp_site
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_tomcat::apache_proxy_ajp_site($port, $ssl=false, $serveralias=false, $documentroot=false, $ensure="present",
                                         $tomcat_tag="tomcat_${environment}") {
  apache::site_config { "${name}":
    serveralias  => $serveralias,
    documentroot => $documentroot,
    template     => "kbp_tomcat/apache/mod-proxy-ajp.conf",
    require      => Apache::Module["proxy_ajp"],
  }

  kbp_apache::site { "${name}":
    ensure => $ensure,
  }

#  kbp_tomcat::apache_proxy_ajp_site { "${domain}":
#    ssl          => $ssl,
#    port         => $ajp13_connector_port,
#    serveralias  => $serveralias,
#    documentroot => $documentroot,
#    ensure       => $ensure;
#  }
}

# Define: kbp_tomcat::user
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_tomcat::user ($username=false, $password, $role, $tomcat_tag="tomcat_${environment}") {
  if !$username {
    $the_username = $name
  } else {
    $the_username = $username
  }

  gen_tomcat::user { "${the_username}":
    username   => $the_username,
    password   => $password,
    role       => $role,
    tomcat_tag => $tomcat_tag;
  }
}

# Define: kbp_tomcat::role
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_tomcat::role ($role=false, $tomcat_tag="tomcat_${environment}") {
  if !$role {
    $the_role = $name
  } else {
    $the_role = $role
  }

  gen_tomcat::role { "${the_role}":
    role       => $the_role,
    tomcat_tag =>  $tomcat_tag;
  }
}
