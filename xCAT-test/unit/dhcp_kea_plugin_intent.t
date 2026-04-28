use strict;
use warnings;
no warnings 'once';

use FindBin;
use lib "$FindBin::Bin/../../perl-xCAT";

use Test::More;

BEGIN {
    package xCAT::Table;
    our $networks;
    sub new {
        my ( $class, $name ) = @_;
        return $name eq 'networks' ? $networks : undef;
    }
    $INC{'xCAT/Table.pm'} = __FILE__;

    package xCAT::TableUtils;
    sub getTftpDir { return '/tftpboot'; }
    sub get_site_attribute { return; }
    $INC{'xCAT/TableUtils.pm'} = __FILE__;

    package xCAT::Utils;
    sub osver { return 'rhels9'; }
    sub runcmd { return; }
    $INC{'xCAT/Utils.pm'} = __FILE__;

    package xCAT::NetworkUtils;
    sub import {
        my $caller = caller;
        no strict 'refs';
        *{"${caller}::getipaddr"} = \&getipaddr;
    }
    sub getipaddr { return '10.0.0.1'; }
    sub my_ip_facing { return ( 0, '10.0.0.1' ); }
    sub thishostisnot { return 0; }
    sub ip_forwarding_enabled { return 0; }
    sub nodeonmynet { return 1; }
    $INC{'xCAT/NetworkUtils.pm'} = __FILE__;

    package xCAT::ServiceNodeUtils;
    sub getSNList { return; }
    $INC{'xCAT/ServiceNodeUtils.pm'} = __FILE__;

    package xCAT::NodeRange;
    $INC{'xCAT/NodeRange.pm'} = __FILE__;
}

require "$FindBin::Bin/../../xCAT-server/lib/xcat/plugins/dhcp.pm";

{
    package DHCPKeaIntentNetTable;
    sub new {
        my ( $class, $entry ) = @_;
        return bless { entry => $entry }, $class;
    }
    sub getAllAttribs {
        my ( $self, @attrs ) = @_;
        return { domain => $self->{entry}{domain} } if @attrs == 1 && $attrs[0] eq 'domain';
        return { %{ $self->{entry} } };
    }
    sub getAttribs {
        my ($self) = @_;
        return { %{ $self->{entry} } };
    }
    sub close { return; }
}

my %network_entry = (
    net          => '10.0.0.0',
    mask         => '255.255.255.0',
    mgtifname    => 'eth0',
    dynamicrange => '10.0.0.100-10.0.0.150',
    domain       => 'cluster.test',
    tftpserver   => '<xcatmaster>',
);

{
    no warnings 'redefine';
    local *xCAT_plugin::dhcp::kea_ipv4_routes = sub {
        return (
            [ '10.0.0.0',    'eth0',  '255.255.255.0', '' ],
            [ '192.168.1.0', 'enp3s0', '255.255.255.0', '' ],
        );
    };
    local *xCAT_plugin::dhcp::kea_boot_client_classes = sub { return []; };
    local *xCAT_plugin::dhcp::kea_option_defs = sub { return []; };
    local *xCAT_plugin::dhcp::kea_global_option_data = sub { return []; };
    local *xCAT_plugin::dhcp::kea_dhcp_lease_time = sub { return 43200; };
    local *xCAT_plugin::dhcp::kea_control_agent_enabled = sub { return 0; };

    local $xCAT::Table::networks = DHCPKeaIntentNetTable->new( \%network_entry );

    my $intent = xCAT_plugin::dhcp::kea_build_dhcp4_intent( bless({}, 'DHCPKeaIntentBackend'), {} );

    is_deeply( $intent->{interfaces}, ['eth0'], 'empty dhcpinterfaces infers the local provisioning interface' );
    is( scalar @{ $intent->{subnets} }, 1, 'empty dhcpinterfaces still renders local routed subnet' );
    is( $intent->{subnets}[0]{subnet}, '10.0.0.0/24', 'rendered subnet comes from local route' );
}

{
    no warnings 'redefine';
    local *xCAT::NetworkUtils::thishostisnot = sub { return 1; };

    my $nettab = DHCPKeaIntentNetTable->new(
        {
            %network_entry,
            dhcpserver => 'service-node-a',
        }
    );

    my $subnet = xCAT_plugin::dhcp::kea_subnet4_intent( $nettab, '10.0.0.0', '255.255.255.0', 'eth0', 0, 1, 80 );
    ok( !defined( $subnet->{dynamicrange} ), 'non-owning Kea server does not render dynamic pool' );
}

{
    no warnings 'redefine';
    local *xCAT::NetworkUtils::thishostisnot = sub { return 0; };

    my $nettab = DHCPKeaIntentNetTable->new(
        {
            %network_entry,
            dhcpserver => 'service-node-a',
        }
    );

    my $subnet = xCAT_plugin::dhcp::kea_subnet4_intent( $nettab, '10.0.0.0', '255.255.255.0', 'eth0', 0, 1, 80 );
    is( $subnet->{dynamicrange}, $network_entry{dynamicrange}, 'owning Kea server renders dynamic pool' );
}

done_testing();
