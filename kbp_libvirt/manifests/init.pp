# Author: Kumina bv <support@kumina.nl>

# Class: kbp_libvirt
#
# Actions:
#  Undocumented
#
# Depends:
#  Undocumented
#  gen_puppet
#
define kbp_libvirt ($on_crash="destroy", $on_reboot="restart") {
  include munin::client
  class { "libvirt":
    on_crash  => $on_crash,
    on_reboot => $on_reboot;
  }

  gen_ferm::mod { "Allow bridged packets":
    chain  => "FORWARD",
    mod    => "physdev",
    param  => "physdev-is-bridged",
    action => "ACCEPT";
  }

  file {
    "/etc/libvirt/qemu/networks/default.xml":
      require => Kpackage["libvirt-bin"],
      ensure  => absent;
    "/etc/libvirt/storage":
      ensure  => directory,
      require => Kpackage["libvirt-bin"],
      mode    => 755;
    "/etc/libvirt/storage/autostart":
      ensure  => directory,
      require => File["/etc/libvirt/storage"],
      mode    => 755;
    "/etc/libvirt/storage/guest.xml":
      content => template("kbp_libvirt/guest.xml"),
      require => File["/etc/libvirt/storage"];
    "/etc/libvirt/storage/autostart/guest.xml":
      ensure  => "/etc/libvirt/storage/guest.xml",
      require => File["/etc/libvirt/storage/autostart"];
  }

  if versioncmp($lsbdistrelease, "5.0") < 0 {
    munin::client::plugin { ["libvirt-blkstat", "libvirt-cputime", "libvirt-ifstat", "libvirt-mem"]:
      require     => [Package["python-libvirt", "python-libxml2"],Munin::Client::Plugin::Config["libvirt"]],
      script_path => "/usr/local/share/munin/plugins";
    }

    include gen_base::python-libvirt
    kpackage { "python-libxml2":
      ensure => latest;
    }
  } else {
    include gen_base::munin-libvirt-plugins

    munin::client::plugin { ["libvirt-blkstat", "libvirt-cputime", "libvirt-ifstat", "libvirt-mem"]:
      require     => [Package["munin-libvirt-plugins"],Munin::Client::Plugin::Config["libvirt"]],
      script_path => "/usr/share/munin/plugins";
    }
  }

  munin::client::plugin::config { "libvirt":
    section => "libvirt-*",
    content => "user root";
  }
}
