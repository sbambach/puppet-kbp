class kbp_nfs::client {
	include gen_nfs::client
	include kbp_trending::nfs

	@@ferm::rule { "NFS connections from ${fqdn}":
		saddr  => $fqdn,
		proto  => "(tcp udp)",
		action => "ACCEPT",
		tag    => "nfs_${environment}";
	}
}

define kbp_nfs::client::mount ($source) {
	include kbp_nfs::client

	gen_nfs::client::mount { $name:
		source => $source,
	}

	# Exclude this mount from the backups
	line { "Exclude NFS mount ${name} from backups.":
		file    => "/etc/backup/excludes",
		content => "${name}",
		require => Kpackage["offsite-backup"],
	}

	# Check if the mount is still available, if not, remount
	exec { "/bin/mount -o remount ${name}":
		unless  => "/bin/sh -c 'cd ${name}'",
		require => Gen_nfs::Client::Mount["${name}"],
	}
}
