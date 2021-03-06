# The ITM Jira server is deployed on blade-308. It's IP is added to DNS as jira.nl.informatm.com
# TODO Create define for JIRA plugins. They should be downloaded, added to the lib/ or WEB-INF dir in ${root}/source/atlassian-jira directory and the WAR should be rebuild and redeployed

class kbp_jira ($version="4.4", $db_name="jira", $db_username="jira", $db_password, $db_server="localhost", $domain=$fqdn, $max_check_attempts="5") {
  $root="/srv/jira"
  class { "kbp_tomcat":
    java_opts   => "-Dorg.apache.jasper.runtime.BodyContentImpl.LIMIT_BUFFER=true -Dmail.mime.decodeparameters=true",
    jvm_max_mem => "512";
  }
  include kbp_tomcat::mysql
  include gen_base::ant
  include gen_base::unzip

  # Create the directories needed for jira
  file {
    "${root}":
      ensure  => directory,
      owner   => "tomcat6",
      mode    => 775,
      require => Package["tomcat6"];
    ["${root}/home",
     "${root}/home/installed-plugins"]:
      ensure  => directory,
      owner   => "tomcat6",
      mode    => 775,
      require => [Package["tomcat6"], File["${root}"]];
    "${root}/source/atlassian_jira/edit-webapp/WEB-INF/classes/jira-application.properties":
      content => "jira.home = ${root}/home",
      mode    => 674,
      require => Exec["Get JIRA"],
      notify  => Exec["Build JIRA WAR"];
    "${root}/source/atlassian_jira/build.xml":
      content => template("kbp_jira/build.xml"),
      mode    => 674,
      require => Exec["Get JIRA"],
      notify  => Exec["Build JIRA WAR"];
    "${root}/source/atlassian_jira/edit-webapp/WEB-INF/lib":
      ensure  => directory,
      mode    => 775,
      require => Exec["Get JIRA"],
      notify  => Exec["Get extra JIRA jars"];
    "${root}/home/dbconfig.xml":
      content => template("kbp_jira/dbconfig.xml"),
      mode    => 670,
      owner   => "tomcat6";
    "/usr/local/bin/get_jira":
      content => template("kbp_jira/get_jira.sh"),
      mode    => 755;
    "/usr/local/bin/build_war":
      content => template("kbp_jira/build_war.sh"),
      mode    => 755;
  }

  setfacl { "${root} tomcat6":
    dir          => $root,
    acl          => "user:tomcat6:rwx",
    make_default => true,
    require      => [File[$root], Package["tomcat6"]];
  }

  exec {
    "Get JIRA":
      command     => "/usr/local/bin/get_jira ${root} ${version}",
      unless      => "/usr/bin/test -f ${root}/source/DOWNLOADED_${version}",
      require     => File["/usr/local/bin/get_jira", $root];
    "Build JIRA WAR":
      command     => "/usr/local/bin/build_war ${root}",
      refreshonly => true,
      notify      => Service["tomcat6"],
      require     => [File["/usr/local/bin/build_war"], Package["ant"]];
    "Get extra JIRA jars":
      command     => "/usr/bin/wget -O ${root}/source/jira-jars-tomcat-distribution-${version}-tomcat-6x.zip -q \"http://www.atlassian.com/software/jira/downloads/binary/jira-jars-tomcat-distribution-${version}-tomcat-6x.zip\" && unzip -o ${root}/source/jira-jars-tomcat-distribution-${version}-tomcat-6x.zip -d ${root}/source/atlassian_jira/edit-webapp/WEB-INF/lib;",
      unless      => "/usr/bin/test -f ${root}/source/atlassian_jira/edit-webapp/WEB-INF/lib/commons-logging-1.1.1.jar",
      notify      => Exec["Build JIRA WAR"],
      require     => [File["${root}/source/atlassian_jira/edit-webapp/WEB-INF/lib"], Package["unzip"]];
  }

  kbp_tomcat::webapp { "jira":
    war                 => "${root}/source/atlassian_jira/dist-tomcat/tomcat-6/atlassian-jira-${version}.war",
    urlpath             => "jira",
    root_app            => true,
    additional_context_settings => {'debug' => '0', 'useHttpOnly' => 'true'},
  }

  kaugeas {
    'Context resource UserTransaction for jira':
      file    => '/srv/tomcat/conf/Catalina/localhost/jira.xml',
      lens    => 'Xml.lns',
      changes => ["set Context/Resource[#attribute/name='UserTransaction']/#attribute/name 'UserTransaction'",
                  "set Context/Resource[#attribute/name='UserTransaction']/#attribute/auth 'Container'",
                  "set Context/Resource[#attribute/name='UserTransaction']/#attribute/type 'javax.transaction.UserTransaction'",
                  "set Context/Resource[#attribute/name='UserTransaction']/#attribute/factory 'org.objectweb.jotm.UserTransactionFactory'",
                  "set Context/Resource[#attribute/name='UserTransaction']/#attribute/jotm.timeout '60'"],
      require => File['/srv/tomcat/conf/Catalina/localhost/jira.xml'];
    'Context manager for jira':
      file    => '/srv/tomcat/conf/Catalina/localhost/jira.xml',
      lens    => 'Xml.lns',
      changes => ["set Context/Manager[#attribute/pathname='']/#attribute/pathname ''"],
      require => File['/srv/tomcat/conf/Catalina/localhost/jira.xml'];
  }

  # TODO Allow the DB to reside on another machine.
  class { "kbp_mysql::server":
    mysql_name => "jira";
  }

  kbp_tomcat::apache_proxy_ajp_site { $domain:
    port                       => 8009,
    monitor_max_check_attempts => $max_check_attempts,
    monitor_path               => "/jira/secure/Dashboard.jspa";
  }

  mysql::server::db { "${db_name}":
    use_utf8 => true;
  }

  mysql::server::grant { "Permissions for ${db_username} on ${db_name}":
    user     => $db_username,
    db       => $db_name,
    password => $db_password;
  }
}

define kbp_jira::plugin ($url, $pluginversion=2) {
  $pluginlocation = $pluginversion ? {
    2 => "/srv/jira/home/installed-plugins",
    1 => "/srv/jira/source/atlassian_jira/edit-webapp/WEB-INF/lib",
    default => fail("you fail at plugins!")
  }
  exec { "install JIRA plugin ${name}":
    command => "/usr/bin/wget --content-disposition -q -O ${pluginlocation}/${name} \"${url}\"",
    unless  => "/usr/bin/test -f ${pluginlocation}/${name}",
    notify  => $pluginversion ? {
      1 => Exec["Build JIRA WAR"],
      default => undef,
    },
    require => [Exec["Get JIRA"], File[$pluginlocation]];
  }
}
