class kbp_base {
	include lvm
	include gen_puppet::concat
	include gen_base
	include sysctl
	include kbp_acpi
	include kbp_apt
	include kbp_puppet
	include kbp_ssh
	include kbp_vim
	include kbp_time
	include kbp_sudo
	include kbp_icinga::client
	if $is_virtual == "false" {
		include kbp_physical
	}

	gen_sudo::rule {
		"User root has total control":
			entity            => "root",
			as_user           => "ALL",
			command           => "ALL",
			password_required => true,
			order             => 10; # legacy, only used on lenny systems
		"Kumina default rule":
			entity            => "%root",
			as_user           => "ALL",
			command           => "ALL",
			password_required => true,
			order             => 10; # legacy, only used on lenny systems
	}

	concat { "/etc/ssh/kumina.keys":
		owner => "root",
		group => "root",
		mode  => 0644,
	}

	define staff_user($ensure = "present", $fullname, $uid, $password_hash, $sshkeys = "") {
		$username = $name
		user { "$username":
			comment 	=> $fullname,
			ensure 		=> $ensure,
			gid 		=> "kumina",
			uid 		=> $uid,
			groups 		=> ["adm", "staff", "root"],
			membership 	=> minimum,
			shell	 	=> "/bin/bash",
			home 		=> "/home/$username",
			require 	=> File["/etc/skel/.bash_profile"],
			password 	=> $password_hash,
		}

		if $ensure == "present" {
			kfile { "/home/$username":
				ensure => directory,
				mode 	=> 750,
				owner 	=> "$username",
				group 	=> "kumina",
				require => [User["$username"], Group["kumina"]],
			}

			kfile { "/home/$username/.ssh":
				ensure 	=> directory,
				mode 	=> 700,
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			kfile { "/home/$username/.ssh/authorized_keys":
				ensure 	=> present,
				content => "$sshkeys",
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			gen_puppet::concat::add_content { "Add $username to Kumina SSH keyring":
				target  => "/etc/ssh/kumina.keys",
				content => "# $fullname <$username@kumina.nl>\n$sshkeys",
			}

			kfile { "/home/$username/.bashrc":
				ensure 	=> present,
				content => template("kbp_base/home/$username/.bashrc"),
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			kfile { "/home/$username/.bash_profile":
				ensure 	=> present,
				source 	=> "kbp_base/home/$username/.bash_profile",
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			kfile { "/home/$username/.bash_aliases":
				ensure 	=> present,
				source 	=> "kbp_base/home/$username/.bash_aliases",
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			kfile { "/home/$username/.darcs":
				ensure => directory,
				mode 	=> 755,
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			kfile { "/home/$username/.tmp":
				ensure => directory,
				mode 	=> 755,
				owner 	=> "$username",
				group 	=> "kumina",
				require => File["/home/$username"],
			}

			kfile { "/home/$username/.darcs/author":
				ensure => present,
				content => "$fullname <$username@kumina.nl>\n",
				group => "kumina",
				require => File["/home/$username/.darcs"],
			}

			kfile { "/home/$username/.gitconfig":
				ensure => present,
				content => template("kbp_base/git/.gitconfig"),
				group => "kumina";
			}

			kfile { "/home/$username/.reportbugrc":
				ensure => present,
				content => "REPORTBUGEMAIL=$username@kumina.nl\n",
				group => "kumina";
			}
		} else {
			kfile { "/home/$username":
				ensure  => absent,
				force   => true,
				recurse => true,
			}
		}
	}

	# Add the Kumina group and users
	# XXX Needs to do a groupmod when a group with gid already exists.
	group { "kumina":
		ensure => present,
		gid => 10000,
	}

	staff_user {
		"tim":
			fullname      => "Tim Stoop",
			uid           => 10001,
			password_hash => "BOGUS",
			sshkeys       => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcRYiKZ1yPUU8+oRaDI/TyRSyFu2fwbknvr/Q3rwbQZm2K8iTfY4/WUeu/oSZOnCn5uoNjGax88RZx92DK0yYpOHtUwG/nShtTwte0Mx4zW8Sfq343OPle2b2gp/0V6dx1Nq21rmQrh0Ql23Thmi33cmKUvPgwYXvsIKfM68J2bG9+hIiucQX0AY7oH8UCX6uJmjOB2nPBsCMAmBHLsfV9LTvSobYAJLEt0m2wV+BqPZW5zLj7HyrGCDa5+85EB4MuQsiYuVdAjQJ3JF/FD0w7LrtuwhKZuS/Qwn4vXah1FlTBlIfw6IxWrQ0+CBCx4h/E4lbxgLTHCB4sanhUGKQtVV1/CFEA9GYCtDbNepFmjuZM1IubarpJmMicOebIW6yT9/035jKuS+nJG2xOLfV4MNPDkuAwqgg1DJ1JmqpG8y1+rHuswbXhlxlfKw/SEooH6I8NDv+TxHSkyo5siacNRsfQ8rQf9fKJdhD0twZuOZU8Zz9wpFz6VCYMkgKp05U= smartcard Tim Stoop\n";
		"kees":
			fullname      => "Kees Meijs",
			password_hash => "BOGUS",
			uid           => 10002,
			ensure        => absent;
		"mike":
			fullname      => "Mike Huijerjans",
			uid           => 10000,
			password_hash => "BOGUS",
			ensure        => absent;
		"pieter":
			fullname      => "Pieter Lexis",
			uid           => 10005,
			password_hash => "BOGUS",
			sshkeys       => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCY+AGY7jg8z5DBdajz04kGz9yyDcmhDBqW1n3G6LfkxQ0neOWGqtQi7uBDGoamhc2y6uuFHaR5vUk0uvsxhch6DjJ4xlCZGjiSqWDaUD7QSj70PTYvy2Ol0nqDXWbA0g4gNovTE3dNH1TyAQEJ7Ox1qW5s+RgSwLGh+suIyjsbjgR/t+tMMqDSEBN4Hbqbvfr/RJMpK/yA+FFTFllVN0nb+EuX4L2pnzjpIBIShXdL+gfjghOpJ31dpgWxgUrTXGOLXtB97CjGZ4MIKvPLkOpZPILIkADcx1FNg9lwd/QiLeTnWg7fPMbc4BIfEWvVp7UoCU/VmjJlSuuOgKtDAq0J pieter@kumina.nl\n";
		"rutger":
			fullname      => "Rutger Spiertz",
			uid           => 10003,
			password_hash => "BOGUS",
			sshkeys       => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMZBz0sRqmfs4QT4dXVQeMIc+PdDChsjSUQv+SkN//z+igMw6qe5acC8EXUk5CR7VfaOjttp+sgoOxsvFPdFnrcozUsssnUynfVQ4GHCpDu0iOoUtz+WuGGonauAimhFsO2apkYLlO2qipt/z6B+bPQsbOxIVLpLLCa1kFKux7Td4vGddxbCxtFECd/4QUuS42G5q8nET3cdiqHM+QHXs1bnOqa6nxOxhnKX1jlqPT5nwdd8pI+RChGcjD4UofL9IYtz+Nd8wZi/h0tcOUh/ORV1bpJFwTCdWwaQ7Z7bf2Aanzn6iJz14nM0n19EOdvcB5NS/1mE54U9S3qJN+fQT3bOm47R07BIXmCEah6uZUAezkzsnXAsntgn2YDZFhjX+6Xd0iALAlhOyOMVfjJ0cq/qv1WhqScyOOETZhwOjLm4lewigpRnctJBt87p8MArPTBbJJA4TayC9eP6IfZ6plu0Be+W+xvrh/ga3oxMiyg6LWCf2yeTRUut7aIyswxY8= rutger@kumina.nl\n";
		"ed":
			fullname      => "Ed Schouten",
			uid           => 10004,
			password_hash => "BOGUS",
			sshkeys       => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCXah/YknMvN7CCOAK642FZfnXYVZ2uYZsy532v8pOISzH9W8mJ4FqBi0g1oAFhTZs0VNc9ouNfMDG178LSITL+ui/6T9exOEd4a0pCXuArVFmc5EVEUl3F+/qZPcOnWs7e3KaiV1dGLYDI0LhdG9ataHHR3sSPI/YAhroDLDTSVqFURXL7eyqR/aEv7nPEkY4zhQQzTECSQdadwEtGnovjNNL2aEj8rVVle5lVjbSk4N7x0ixyb4eTPB1z5FnwAlVkxHhTnsxTK28ulkrVCgKE30KS97dRG/EjA81pOzajRYTyLztqSkJnpKpL/lPfUCG7VkNfQKF+0O/KRhUfr2zb cardno:00050000057D\n";
	}

	# Packages we like and want :)
	kpackage {
		["binutils","console-tools","realpath"]:
			ensure => installed;
		["hidesvn","bash-completion","bc","tcptraceroute","diffstat","host","whois","pwgen"]:
			ensure => latest;
	}

	if versioncmp($lsbdistrelease, 6.0) < 0 {
		kpackage { "tcptrack":
			ensure => latest,
		}
	}

	kfile {
		"/etc/motd.tail":
			source 	=> "kbp_base/motd.tail";
		"/etc/console-tools/config":
			source  => "kbp_base/console-tools/config",
			require => Package["console-tools"];
	}

	exec {
		"uname -snrvm | tee /var/run/motd ; cat /etc/motd.tail >> /var/run/motd":
			refreshonly => true,
			path => ["/usr/bin", "/bin"],
			require => File["/etc/motd.tail"],
			subscribe => File["/etc/motd.tail"];
	}
}

class kbp_base::environment {
	include kbp_monitoring::environment
}
