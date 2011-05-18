define kbp_haproxy::site ($listenaddress, $port=80, $monitoring=true) {
	ferm::rule { "HAProxy forward for ${name}":
		proto  => "tcp",
		dport  => $port,
		action => "ACCEPT";
	}

	if $monitoring {
		kbp_haproxy::monitoring::icinga::site { "${name}":
			address => $listenaddress;
		}
	}
}

class kbp_haproxy::monitoring::icinga {
	define site ($address) {
		$confdir = "${environment}/${name}"

		kbp_icinga::configdir { $confdir:
			sub => $environment;
		}

		kbp_icinga::host { "${name}":
			address => $address;
		}

		kbp_icinga::service { "virtual_host_${name}":
			conf_dir            => $confdir,
			service_description => "Virtual host ${name}",
			hostname            => $name,
			checkcommand        => "check_http_vhost",
			argument1           => $name;
		}
	}
}
