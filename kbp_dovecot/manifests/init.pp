class kbp_dovecot::imap {
	include dovecot::imap

	gen_ferm::rule { "IMAP connections":
		proto  => "tcp",
		dport  => "(143 993)",
		action => "ACCEPT";
	}
}
