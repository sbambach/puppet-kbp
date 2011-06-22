class kbp_bind inherits bind {
	# Needed for the check_dnszone script
	kpackage { ["python-ipaddr","python-argparse","python-dnspython"]:; }

	class { "kbp_trending::bind9":
		method => "munin"
	}

	gen_ferm::rule { "DNS connections":
		proto  => "(tcp udp)",
		dport  => 53,
		action => "ACCEPT";
	}

	@@gen_ferm::rule { "Allow AXFR transfers from ${fqdn}":
		saddr  => $fqdn,
		proto  => "(tcp udp)",
		dport  => 53,
		action => "ACCEPT",
		tag    => "bind_${environment}";
	}
}
