# Author: Kumina bv <support@kumina.nl>

class kbp_postfix::mailgraph {
  include gen_base::mailgraph
}

# Class: kbp_postfix
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_postfix($relayhost=false, $myhostname=$fqdn, $mynetworks="127.0.0.0/8 [::1]/128", $mydestination=false, $mode=false, $mailname=false, $active=false, $incoming=false, $always_bcc=false) {
  if $active {
    class { "postfix":
      relayhost     => $relayhost,
      myhostname    => $myhostname,
      mynetworks    => $mynetworks,
      mydestination => $mydestination,
      mode          => $mode,
      always_bcc    => $always_bcc;
    }
    include kbp_openssl::common

    $real_mailname = $mailname ? {
      false   => $fqdn,
      default => $mailname,
    }

    postfix::alias { ["root: reports+${environment}@kumina.nl","reports: root"]:; }

    file { "/etc/mailname":
      content => "${real_mailname}\n",
      notify  => Service["postfix"],
      require => Package["postfix"];
    }

    gen_munin::client::plugin { ["postfix_mailqueue", "postfix_mailstats", "postfix_mailvolume"]:; }

    gen_munin::client::plugin { ["exim_mailstats"]:
      ensure => absent;
    }

    if $incoming or $mode == "primary" or $mode == "secondary" {
      gen_ferm::rule { "SMTP connections":
        proto  => "tcp",
        dport  => "(25 465)",
        action => "ACCEPT";
      }
    }
  }
}
