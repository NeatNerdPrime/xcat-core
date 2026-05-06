#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

my $pre_sles_path = defined $ENV{XCATROOT} ? "$ENV{XCATROOT}/share/xcat/install/scripts/pre.sles" : '';
$pre_sles_path = "xCAT-server/share/xcat/install/scripts/pre.sles"
    unless -f $pre_sles_path;

plan skip_all => "pre.sles not found" unless -f $pre_sles_path;

my $src = do { local $/; open my $fh, '<', $pre_sles_path or die $!; <$fh> };

like($src, qr/sub set_sles11_uefi_bootloader\b|set_sles11_uefi_bootloader\(\)/, 'SLES UEFI bootloader helper exists');
like($src, qr/install=\.\*sles11/, 'SLES 11 UEFI bootloader change is scoped to SLES 11 install media');
like($src, qr/<loader_type>elilo<\/loader_type>/, 'SLES 11 UEFI install selects elilo');
like($src, qr/<location>mbr<\/location>/, 'legacy MBR template value is replaced at install time');
like($src, qr/if \[ -d \/sys\/firmware\/efi \]; then\s+sed .*?set_sles11_uefi_bootloader/s, 'UEFI default partitioning applies bootloader helper');

done_testing();
