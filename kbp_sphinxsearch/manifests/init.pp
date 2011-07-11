# Author: Kumina bv <support@kumina.nl>

# Class: kbp_sphinxsearch::server
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_sphinxsearch::server {
	include sphinxsearch::server
	include kbp_sphinxsearch::monitoring::icinga::server

	Gen_ferm::Rule <<| tag == "sphinxsearch_${environment}" |>>

	Gen_ferm::Rule <<| tag == "sphinxsearch_monitoring" |>>
}

# Class: kbp_sphinxsearch::monitoring::icinga::server
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
class kbp_sphinxsearch::monitoring::icinga::server {
	kbp_icinga::service { "spinxsearch_server":
		service_description => "Sphinxsearch service",
		check_command       => "check_tcp",
		arguments           => 3312;
	}
}
