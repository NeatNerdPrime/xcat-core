#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../xCAT-probe/lib/perl";

use Test::More;

require probe_utils;

my %netplan = (
    'ethernets.eth0'           => 'renderer: networkd',
    'ethernets.eth0.addresses' => "- 10.0.0.2/24\n",
    'ethernets.eth0.dhcp4'     => 'false',
    'ethernets.eth1'           => 'renderer: networkd',
    'ethernets.eth1.addresses' => "- 10.0.0.3/24\n",
    'ethernets.eth1.dhcp4'     => 'true',
    'vlans.bond0\.123'           => 'renderer: networkd',
    'vlans.bond0\.123.addresses' => "- 10.0.123.5/24\n",
);

{
    no warnings 'redefine';
    local *probe_utils::_command_available = sub { return $_[0] eq 'netplan' ? 1 : 0; };
    local *probe_utils::_netplan_get = sub { return $netplan{ $_[0] }; };

    ok(probe_utils::_netplan_has_static_ip('eth0', '10.0.0.2'), 'static netplan address is detected');
    ok(!probe_utils::_netplan_has_static_ip('eth0', '10.0.0.99'), 'wrong address is not treated as static');
    ok(!probe_utils::_netplan_has_static_ip('eth1', '10.0.0.3'), 'dhcp4 true is not treated as static');
    ok(probe_utils::_netplan_has_static_ip('bond0.123', '10.0.123.5'), 'dotted VLAN interface is escaped for netplan get');
}

done_testing();
