class kbp_syslog::server($environmentonly=false) {
	include "kbp_syslog::server::$lsbdistcodename"

	if ($environmentonly) {
		Ferm::Rule <<| tag == "syslog_${environment}" |>>
	} else {
		Ferm::Rule <<| tag == "syslog" |>>
	}
}

class kbp_syslog::client {
	include "kbp_syslog::client::$lsbdistcodename"

	@@ferm::rule { "Syslog traffic from ${fqdn}_v4":
		saddr  => $fqdn,
		proto  => "udp",
		dport  => 514,
		action => "ACCEPT",
		tag    => ["syslog","syslog_${environment}"];
	}
}

class kbp_syslog::server::etch inherits syslog-ng::server {
	kfile { "/etc/logrotate.d/syslog-ng":
		source => "kbp_syslog/server/logrotate.d/syslog-ng";
	}
}

class kbp_syslog::client::etch inherits sysklogd::client {
}

class kbp_syslog::server::lenny inherits rsyslog::server {
	include kbp_logrotate
	gen_logrotate::rotate { "rsyslog":
		log => ["/var/log/syslog", "/var/log/mail.info", "/var/log/mail.warn",
			"/var/log/mail.err", "/var/log/mail.log", "/var/log/daemon.log",
			"/var/log/kern.log", "/var/log/auth.log", "/var/log/user.log",
			"/var/log/lpr.log", "/var/log/cron.log", "/var/log/debug",
			"/var/log/messages"],
		options => ["daily", "rotate 90", "missingok", "notifempty", "compress", "sharedscripts"],
		postrotate => "invoke-rc.d rsyslog reload > /dev/null";
	}
}

class kbp_syslog::client::lenny inherits rsyslog::client {
}

class kbp_syslog::server::squeeze inherits rsyslog::server {
	include kbp_logrotate
	gen_logrotate::rotate { "rsyslog":
		log => ["/var/log/syslog", "/var/log/mail.info", "/var/log/mail.warn",
			"/var/log/mail.err", "/var/log/mail.log", "/var/log/daemon.log",
			"/var/log/kern.log", "/var/log/auth.log", "/var/log/user.log",
			"/var/log/lpr.log", "/var/log/cron.log", "/var/log/debug",
			"/var/log/messages"],
		options => ["daily", "rotate 90", "missingok", "notifempty", "compress", "sharedscripts"],
		postrotate => "invoke-rc.d rsyslog reload > /dev/null";
	}
}

class kbp_syslog::client::squeeze inherits rsyslog::client {
}

# Additional options
class kbp_syslog::server::mysql {
	include kbp_syslog::server
	include "kbp_syslog::mysql::$lsbdistcodename"
}

class kbp_syslog::mysql::etch {
	err ("This is not implemented for Etch or earlier!")
}

class kbp_syslog::mysql::lenny inherits rsyslog::mysql {
}
