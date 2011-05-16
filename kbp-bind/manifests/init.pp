class kbp-bind inherits bind {
	include munin::client

# This doesn't work on some hosts, like web.kumina.nl
# Need to find out why.
#	munin::client::plugin { "bind9_rndc":
#		ensure => present,
#	}

#	munin::client::plugin::config { "bind9_rndc":
#		content => "env.querystats /var/cache/bind/named.stats\nuser bind",
#	}

	ferm::rule { "DNS connections":
		proto  => "(tcp udp)",
		dport  => 53,
		action => "ACCEPT";
	}

	@@ferm::rule { "Allow AXFR transfers from ${fqdn}":
		saddr  => $fqdn,
		proto  => "(tcp udp)",
		dport  => 53,
		action => "ACCEPT",
		tag    => "bind_${environment}";
	}
}
