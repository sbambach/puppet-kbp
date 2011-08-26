# Author: Kumina bv <support@kumina.nl>

# Class: kbp_puppet
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_puppet {
	include gen_puppet

#	exec { "Mount /var with acl":
#		command => '/usr/bin/awk \'/var/ { if($4 !~ /acl/) $4 = $4",acl" } ; { print }\' /etc/fstab > /etc/fstab.net && mv /etc/fstab{.net,} && /bin/mount -o remount /var';
#	}

#	setfacl { "/var/lib/puppet_group":
#		dir          => "/var/lib/puppet",
#		acl          => "group:kumina:rwx",
#		make_default => true,
#		require      => Exec["Mount /var with acl"];
#	}

	gen_apt::preference { ["puppet","puppet-common"]:; }
}

# Class: kbp_puppet::test_default_config
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_puppet::test_default_config {
	include gen_puppet::puppet_conf

	# Default config for all our puppet clients
	gen_puppet::set_config {
		"logdir":      value => '/var/log/puppet';
		"vardir":      value => '/var/lib/puppet';
		"ssldir":      value => '/var/lib/puppet/ssl';
		"rundir":      value => '/var/run/puppet';
		# Single quotes in the next resources prevent them being expanded
		"factpath":    value => '$vardir/lib/facter';
		"templatedir": value => '$confdir/templates';
		"pluginsync":  value => 'true';
		"environment": value => $environment;
		"configtimeout":
			value   => "300",
			section => "agent";
	}
}

# Class: kbp_puppet::vim
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_puppet::vim {
	include kbp_vim::puppet
}
