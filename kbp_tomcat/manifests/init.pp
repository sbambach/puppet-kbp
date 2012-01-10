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
  include kbp_apache_new

  class { "gen_tomcat":
    ajp13_connector_port => $ajp13_connector_port,
    java_opts            => $java_opts,
    jvm_max_mem          => $jvm_max_mem;
  }

  # Enable mod-proxy-ajp
  kbp_apache_new::module { "proxy_ajp":; }

  # Add /usr/share/java/*.jar to the tomcat classpath
  kfile { "/srv/tomcat/conf/catalina.properties":
    source  => "kbp_tomcat/catalina.properties",
    require => [Package["tomcat6"], File["/srv/tomcat/conf"]];
  }

  # Ensure that everyone in the group tomcat6 can restart Tomcat
  kbp_sudo::rule { "Allow tomcat manipulation when in the tomcat6 group":
    command           => "/etc/init.d/tomcat6 [a-z]*",
    as_user           => "root",
    entity            => "%tomcat6",
    password_required => false;
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
#  Setup a Tomcat webapp.
#
# Parameters:
#  war
#    The warfile to use for this app.
#  urlpath
#    The path on which the app should be mounted in Tomcat
#  context_xml_content
#    DEPRECATED Extra XML stuff inside the <Context/>. Don't use.
#  root_app
#    Set to true if the ROOT app should point to this app.
#  tomcat_tag
#    The default tag to use.
#  additional_context_settings
#    Additional options to set inside the <Context/> tag. Like debug and stuff. Should be a hash like:
#    { "debug" => { value => "5" }, "reloadable" => { value => true } }
#  environment_settings
#    Environment variables to set within this Tomcat Context. Should be a hash like:
#    { "emailHost" => { value => "smtp", var_type => "java.lang.String" } }
#  valve_settings
#    Valves to open for specific IP addresses within this Tomcat Context.
#  datasource_settings
#    JNDI Datasources for this Tomcat Context. Should be a hash like:
#    { "jdbc/WBISDataSource" => { username => "wbis", password => "verysecret", url => "jdbc:mysql://mysql-rw/wbis",
#                                 max_active => "8", max_idle => "4", driver => "com.mysql.jdbc.Driver" } }
#
# Depends:
#  gen_tomcat
#  gen_puppet
#
define kbp_tomcat::webapp($war="", $urlpath="/", $context_xml_content=false, $root_app=false, $tomcat_tag="tomcat_${environment}",
                          $additional_context_settings = false, $environment_settings = false, $valve_settings = false,
                          $datasource_settings = false) {
  gen_tomcat::context { $name:
    tomcat_tag          => $tomcat_tag,
    war                 => $war,
    urlpath             => $urlpath,
    context_xml_content => $context_xml_content,
    root_app            => $root_app;
  }

  if $additional_context_settings {
    # This is a very elaborate workaround for not being able to add an option
    # to create_resources. Solved when puppet bug #9768 is fixed.
    # This would then be enough:
    #  - create_resources("gen_tomcat::additional_context_setting",$additional_context_settings, {context => $name})
    $contextkeys = hash_keys($additional_context_settings)
    kbp_tomcat::additional_context_setting { $contextkeys:
      context => $name,
      hash    => $additional_context_settings,
    }
  }

  if $environment_settings {
    # This is a very elaborate workaround for not being able to add an option
    # to create_resources. Solved when puppet bug #9768 is fixed.
    # This would then be enough:
    #  - create_resources("gen_tomcat::environment",$environment_settings, {context => $name})
    $environmentkeys = hash_keys($environment_settings)
    kbp_tomcat::environment_setting { $environmentkeys:
      context => $name,
      hash    => $environment_settings,
    }
  }

  if $valve_settings {
    # This is a very elaborate workaround for not being able to add an option
    # to create_resources. Solved when puppet bug #9768 is fixed.
    # This would then be enough:
    #  - create_resources("gen_tomcat::valve",$valve_settings, {context => $name})
    $valvekeys = hash_keys($valve_settings)
    kbp_tomcat::valve_setting { $valvekeys:
      context => $name,
      hash    => $valve_settings,
    }
  }

  if $datasource_settings {
    # This is a very elaborate workaround for not being able to add an option
    # to create_resources. Solved when puppet bug #9768 is fixed.
    # This would then be enough:
    #  - create_resources("gen_tomcat::datasource",$datasource_settings, {context => $name})
    $datasourcekeys = hash_keys($datasource_settings)
    kbp_tomcat::datasource_setting { $datasourcekeys:
      context => $name,
      hash    => $datasource_settings,
    }
  }
}

# Define: kbp_tomcat::additional_context_setting
#
# Actions:
#  A dirty workaround for #9768 (puppet bug).
#
define kbp_tomcat::additional_context_setting ($context, $hash) {
  gen_tomcat::additional_context_setting { "${name}":
    context      => $context,
    setting_name => $name,
    value        => $hash[$name],
  }
}

# Define: kbp_tomcat::environment_setting
#
# Actions:
#  A dirty workaround for #9768 (puppet bug).
#
define kbp_tomcat::environment_setting ($context, $hash) {
  gen_tomcat::environment { "${name}":
    context  => $context,
    var_name => $name,
    value    => $hash[$name]["value"],
    var_type => $hash[$name]["var_type"],
  }
}

# Define: kbp_tomcat::valve_setting
#
# Actions:
#  A dirty workaround for #9768 (puppet bug).
#
define kbp_tomcat::valve_setting ($context, $hash) {
  gen_tomcat::valve { "${name}":
    context   => $context,
    classname => $name,
    allow     => $hash[$name]["allow"],
  }
}

# Define: kbp_tomcat::datasource_setting
#
# Actions:
#  A dirty workaround for #9768 (puppet bug).
#
define kbp_tomcat::datasource_setting ($context, $hash) {
  gen_tomcat::datasource { "${name}":
    context    => $context,
    resource   => $name,
    username   => $hash[$name]["username"],
    password   => $hash[$name]["password"],
    url        => $hash[$name]["url"],
    max_active => $hash[$name]["max_active"],
    max_idle   => $hash[$name]["max_idle"],
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
define kbp_tomcat::apache_proxy_ajp_site($ensure="present", $port=8009, $ssl=false, $serveralias=false, $documentroot="/srv/www/${name}", $tomcat_tag="tomcat_${environment}",
    $sourcepath="/", $urlpath="/") {
  $fullname = $ssl ? {
    false => "${name}_80",
    true  => "${name}_443",
  }

  kbp_apache_new::site { $name:
    ensure       => $ensure,
    serveralias  => $serveralias,
    documentroot => $documentroot,
    require      => Kbp_apache_new::Module["proxy_ajp"],
  }

  kbp_apache_new::vhost_addition { "${fullname}/tomcat_proxy":
    content => template("kbp_tomcat/apache/tomcat_proxy");
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
