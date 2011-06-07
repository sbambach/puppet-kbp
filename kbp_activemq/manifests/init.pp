class kbp_activemq {
	include gen_activemq
	include kbp_ferm

	kfile {
		"/etc/activemq/activemq.xml":
			source  => "kbp_activemq/activemq.xml",
			notify  => Exec["/bin/rm -Rf /var/lib/activemq/*"],
			require => Package["activemq"];
		"/etc/activemq/jetty.xml":
			source  => "kbp_activemq/jetty.xml",
			notify  => Exec["reload-activemq"],
			require => Package["activemq"];
	}

	exec { "/bin/rm -Rf /var/lib/activemq/*":
		refreshonly => true,
		notify      => Service["activemq"],
	}

	# Open the management port
	gen_ferm::rule { "Connections to admin port":
		dport  => "8161",
		proto  => "tcp",
		saddr  => "${fqdn}",
		action => "ACCEPT",
	}
}
