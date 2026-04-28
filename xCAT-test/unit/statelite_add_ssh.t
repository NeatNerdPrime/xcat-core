#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

my $script_path = defined $ENV{XCATROOT} ? "$ENV{XCATROOT}/share/xcat/netboot/add-on/statelite/add_ssh" : '';
$script_path = "xCAT-server/share/xcat/netboot/add-on/statelite/add_ssh"
    unless -f $script_path;

plan skip_all => "add_ssh not found" unless -f $script_path;

my $script = do { local $/; open my $fh, '<', $script_path or die $!; <$fh> };

like($script, qr/MaxStartups 100:30:200/, 'add_ssh caps MaxStartups below systemd soft nofile limit');
unlike($script, qr/echo\s+"MaxStartups 1024"/, 'add_ssh does not force MaxStartups 1024');

done_testing();
