# Author: Kumina bv <support@kumina.nl>

# Class: kbp_xen-domu-ntp
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_xen-domu-ntp {
	include ntp
	include sysctl

	exec { "/bin/echo 'xen.independent_wallclock = 1' >> '/etc/sysctl.conf'":
		unless => "/bin/grep -Fx 'xen.independent_wallclock = 1' /etc/sysctl.conf";
	}
}
