# Author: Kumina bv <support@kumina.nl>


class kbp_haproxy ($failover = false, $haproxy_tag="haproxy_${environment}", $loglevel="warning") {
	include kbp_trending::haproxy

	class { "gen_haproxy":
		failover  => $failover,
		loglevel  => $loglevel,
		haproxy_tag => $haproxy_tag;
	}
	Gen_ferm::Rule <<| tag == $haproxy_tag |>>
}

# Define: kbp_haproxy::site
#
# Parameters:
#	listenaddress
#		The external IP to listen to
#	port
#		The external port to listen on
#	monitor_site
#		Should this website be monitored?
#	monitoring_ha
#		Is this a High Availibility (24/7) service?
#	monitoring_url
#		The URL to be monitored, should be a status page of some sort
#	monitoring_response
#		The response we should expect from monitoring_url
#	cookie
#		The cookie option from HAProxy(see http://haproxy.1wt.eu/download/1.4/doc/configuration.txt)
#	httpcheck_uri
#		The URI to check if the backendserver is running
#	httpcheck_port
#		The port to check on whether the backendserver is running
#	servername
#		The hostname(or made up name) for the backend server
#	serverport
#		The port for haproxy to connect to on the backend server
#	serverip
#		The IP of the backend server
#	balance
#		The balancing-method to use
#	timeout_connect
#		TCP connection timeout between proxy and server
#	timeout_server_client
#		TCP connection timeout between client and proxy and Maximum time for the server to respond to the proxy
#	timeout_http_request
#		Maximum time for HTTP request between client and proxy
#	haproxy_tag="haproxy_${environment}"
#		Change this when there are multiple loadbalancers in one environment
#
# Actions:
#	Undocumented
#
# Depends:
#	Undocumented
#	gen_puppet
#
define kbp_haproxy::site ($listenaddress, $port=80, $monitor_site=true, $monitoring_ha=false, $monitoring_url=false, $monitoring_response=false, $cookie=false, $make_lbconfig, $httpcheck_uri=false, $httpcheck_port=false, $balance="static-rr", $max_check_attempts=false, $servername=$hostname, $serverip=$ipaddress_eth0, $serverport=80, $timeout_connect="15s", $timeout_server_client="20s", $timeout_http_request="10s", $tcp_sslport=false, $haproxy_tag="haproxy_${environment}") {
	gen_ferm::rule { "HAProxy forward for ${name}":
		proto     => "tcp",
		daddr     => $listenaddress,
		dport     => $port,
		action    => "ACCEPT",
		exported  => true,
		customtag => $haproxy_tag;
	}

	if $make_lbconfig {
		gen_haproxy::site { "${name}":
			listenaddress         => $listenaddress,
			port                  => $port,
			cookie                => $cookie,
			httpcheck_uri         => $httpcheck_uri,
			httpcheck_port        => $httpcheck_port,
			balance               => $balance,
			servername            => $servername,
			serverip              => $serverip,
			serverport            => $serverport,
			timeout_connect       => $timeout_connect,
			timeout_server_client => $timeout_server_client,
			timeout_http_request  => $timeout_http_request,
			haproxy_tag           => $haproxy_tag;
		}
		if $tcp_sslport {
			gen_haproxy::site { "${name}_ssl":
			listenaddress         => $listenaddress,
			port                  => "443",
			mode                  => "tcp",
			httpcheck_uri         => $httpcheck_uri,
			httpcheck_port        => $httpcheck_port,
			balance               => $balance,
			servername            => $servername,
			serverip              => $serverip,
			serverport            => $tcp_sslport,
			timeout_connect       => $timeout_connect,
			timeout_server_client => $timeout_server_client,
			timeout_http_request  => $timeout_http_request,
			haproxy_tag           => $haproxy_tag;
			}

			gen_ferm::rule { "HAProxy forward for ${name}_ssl":
				proto     => "tcp",
				daddr     => $listenaddress,
				dport     => "443",
				action    => "ACCEPT",
				exported  => true,
				customtag => $haproxy_tag;
			}
		}
	}

	if $monitor_site {
		kbp_monitoring::haproxy { "${name}":
			address            => $listenaddress,
			ha                 => $monitoring_ha,
			url                => $monitoring_url,
			port               => $serverport,
			max_check_attempts => $max_check_attempts,
			response           => $monitoring_response;
		}
	}
}
