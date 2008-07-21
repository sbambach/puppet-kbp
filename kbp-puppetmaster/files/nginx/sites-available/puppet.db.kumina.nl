upstream puppet-prod {
	server 127.0.0.1:18140;
	server 127.0.0.1:18141;
}

server {
	listen			172.29.121.4:8140;
	server_name		puppet puppet.db.kumina.nl;
	access_log		/var/log/nginx/puppet.db.kumina.nl.access.log;
	error_log		/var/log/nginx/puppet.db.kumina.nl.error.log;

	ssl			on;
	ssl_verify_client	on;
	ssl_certificate		/var/lib/puppet/ssl/certs/puppet.pem;
	ssl_certificate_key	/var/lib/puppet/ssl/private_keys/puppet.pem;
	ssl_client_certificate	/var/lib/puppet/ssl/certs/ca.pem;

	location / {
		proxy_pass		http://puppet-prod;
		proxy_redirect		off;
		proxy_set_header	Host		$host;
		proxy_set_header	X-Real-IP	$remote_addr;
		proxy_set_header	X-Forwarded-For	$proxy_add_x_forwarded_for;
		proxy_set_header	X-Client-Verify	SUCCESS;
		proxy_set_header	X-SSL-Subject	$ssl_client_s_dn;
		proxy_set_header	X-SSL-Issuer	$ssl_client_i_dn;
	}
}

server {
	listen			172.29.121.15:8140;
	server_name		puppetca puppetca.db.kumina.nl;
	access_log		/var/log/nginx/puppetca.db.kumina.nl.access.log;
	error_log		/var/log/nginx/puppetca.db.kumina.nl.error.log;

	ssl			on;
	ssl_verify_client	off;
	ssl_certificate		/var/lib/puppet/ssl/certs/puppetca.pem;
	ssl_certificate_key	/var/lib/puppet/ssl/private_keys/puppetca.pem;
	ssl_client_certificate	/var/lib/puppet/ssl/certs/ca.pem;

	location / {
		proxy_pass		http://puppet-prod;
		proxy_redirect		off;
		proxy_set_header	Host		$host;
		proxy_set_header	X-Real-IP	$remote_addr;
		proxy_set_header	X-Forwarded-For	$proxy_add_x_forwarded_for;
		proxy_hide_header	X-Client-Verify;
		proxy_hide_header	X-SSL-Subject;
		proxy_hide_header	X-SSL-Issuer;
	}
}
