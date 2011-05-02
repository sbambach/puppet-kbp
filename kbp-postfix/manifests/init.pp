class kbp-postfix inherits postfix {
	include munin::client
	include openssl::common

    munin::client::plugin { ["postfix_mailqueue", "postfix_mailstats", "postfix_mailvolume"]:
		ensure => present,
	}

	munin::client::plugin { ["exim_mailstats"]:
		ensure => absent,
	}

	# The Postfix init script copies /etc/ssl/certs stuff on (re)start, so restart Postfix
	# on changes!
	Service["postfix"] {
		require => File["/etc/ssl/certs"],
		subscribe => File["/etc/ssl/certs"],
	}
}

class kbp-postfix::secondary {
	include kbp-postfix

	ferm::new::rule { "SMTP connections_v46":
		proto  => "tcp",
		dport  => 25,
		action => "ACCEPT";
	}
}
