class kbp_approx {
	include approx

	Kfile <| title == "/etc/approx/approx.conf" |> {
		source => "kbp_approx/approx.conf",
	}

	ferm::rule { "APT proxy":
		proto     => "tcp",
		dport     => "9999",
		action    => "ACCEPT";
	}
}
