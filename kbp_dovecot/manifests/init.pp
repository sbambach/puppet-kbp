# Author: Kumina bv <support@kumina.nl>

# Class: kbp_dovecot::imap
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
class kbp_dovecot::imap(certs, mysql_user = false, mysql_pass = false, mysql_db = false, mysql_host = false) {
  include gen_dovecot::imap

  file {
    "/srv/mail":
      ensure  => directory,
      owner   => "mail",
      group   => "mail",
      mode    => 700;
    "/srv/sieve":
      ensure  => directory,
      owner   => "mail",
      group   => "mail",
      mode    => 700;
    "/etc/dovecot/dovecot-sql.conf":
      content => template("kbp_dovecot/dovecot-sql.conf"),
      mode    => 600;
    "/etc/dovecot/dovecot.conf":
      content => template("kbp_dovecot/dovecot.conf");
  }

  kbp_ssl::keys { $certs:; }


  kbp_ferm::rule {
    "Sieve connections":
      proto  => "tcp",
      dport  => "2000",
      action => "ACCEPT";
    "IMAP connections":
      proto  => "tcp",
      dport  => "(143 993)",
      action => "ACCEPT";
  }
}
